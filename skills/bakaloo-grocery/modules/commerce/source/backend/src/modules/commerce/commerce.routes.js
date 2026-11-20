import { randomUUID, createHash } from 'node:crypto'
import { query, getClient } from '../../config/database.js'
import { success } from '../../utils/apiResponse.js'
import { TotalsEngine } from '../cart/totals-engine.service.js'
import { mediaId } from '../themes/publication.js'
import { OrdersRepository } from './orders.repository.js'

const engine = new TotalsEngine()
const orders = new OrdersRepository()
const customerId = '00000000-0000-4000-8000-000000000322'
const address = { label: 'Home', address: '12 Lake View Road', city: 'Bengaluru' }
const feeConfig = {
  delivery_fee_enabled: true, min_delivery_fee: 25,
  free_delivery_enabled: true, free_delivery_above: 299, delivery_eta_minutes: 25,
}
const appOrigin = process.env.THEME_BUNDLE_APP_ORIGIN ?? 'http://127.0.0.1:4502'

const round = (value) => Math.round((value + Number.EPSILON) * 100) / 100
const uuid = { type: 'string', format: 'uuid' }
const cartItems = {
  type: 'array', minItems: 1, maxItems: 50,
  items: {
    type: 'object', required: ['product_id', 'quantity'], additionalProperties: false,
    properties: { product_id: uuid, quantity: { type: 'integer', minimum: 1, maximum: 50 } },
  },
}
function fail(message, statusCode) {
  return Object.assign(new Error(message), { statusCode })
}

function normalizedLines(items) {
  const quantities = new Map()
  for (const line of items) {
    const id = line.product_id.toLowerCase()
    quantities.set(id, (quantities.get(id) ?? 0) + line.quantity)
  }
  if ([...quantities.values()].some(qty => qty > 50)) throw fail('Limit 50 units per product', 422)
  return [...quantities].sort(([a], [b]) => a.localeCompare(b))
}

// Both quote and order placement use current prices and Bakaloo's totals engine.
async function inspect(runner, normalized, lockRows) {
  const { rows } = await runner.query(
    `SELECT id, name, price, sale_price, unit, stock_quantity
     FROM products WHERE id = ANY($1::uuid[]) AND is_active
     ORDER BY id ${lockRows ? 'FOR UPDATE' : ''}`, [normalized.map(([id]) => id)]
  )
  const products = new Map(rows.map(p => [p.id, p]))
  let itemDiscount = 0
  let itemsSubtotal = 0
  const items = normalized.map(([id, quantity]) => {
    const row = products.get(id)
    if (!row || row.stock_quantity < quantity) {
      throw fail(row ? `Only ${row.stock_quantity} remaining for ${row.name}` : 'A product is unavailable', 409)
    }
    const regular = Number(row.price)
    const sale = Number(row.sale_price)
    const price = sale > 0 && sale < regular ? sale : regular
    const total = round(quantity * price)
    itemsSubtotal += total
    itemDiscount += (regular - price) * quantity
    return { productId: id, name: row.name, unit: row.unit, quantity, price, total }
  })
  const bill = engine.computeBreakdown({ config: feeConfig, itemsSubtotal, itemDiscount })
  return { items, bill, address }
}

function orderView(row) {
  return {
    id: row.id, orderNumber: row.order_number, customer: 'Demo Shopper', status: row.status,
    items: row.items, subtotal: Number(row.subtotal), deliveryFee: Number(row.delivery_fee),
    totalAmount: Number(row.total_amount), paymentMethod: row.payment_method,
    paymentStatus: row.payment_status, deliveryAddress: row.delivery_address, createdAt: row.created_at,
  }
}

async function place(items, requestId, quotedTotal) {
  const normalized = normalizedLines(items)
  const fingerprint = createHash('sha256').update(JSON.stringify(normalized)).digest('hex')
  const client = await getClient()
  try {
    await client.query('BEGIN')
    await client.query('SELECT pg_advisory_xact_lock(hashtextextended($1::text, 82150))', [requestId])
    const { rows: [existing] } = await client.query('SELECT * FROM orders WHERE checkout_request_id = $1', [requestId])
    if (existing) {
      if (existing.checkout_fingerprint !== fingerprint) throw fail('Checkout reference is already in use', 409)
      await client.query('COMMIT')
      return { created: false, order: orderView(existing) }
    }

    const current = await inspect(client, normalized, true)
    if (current.bill.totalPayable !== quotedTotal) throw fail('The total changed. Refresh the quote and try again.', 409)
    await orders.decrementStock(client, current.items)
    const row = await orders.create(client, {
      ...current, number: await orders.generateOrderNumber(client), userId: customerId, requestId, fingerprint,
    }, current.items)
    await client.query('COMMIT')
    return { created: true, order: orderView(row) }
  } catch (error) {
    await client.query('ROLLBACK')
    throw error
  } finally {
    client.release()
  }
}

const productProjection = `p.id, p.name, p.price::float8, p.sale_price::float8,
  p.stock_quantity, p.unit, p.tags, p.thumbnail_url AS image, c.slug AS category, c.id AS "categoryId"`

export default async function commerceRoutes(app) {
  const admin = { preHandler: app.authenticate }

  app.get('/api/v1/catalog', async (_request, reply) => {
    reply.header('Access-Control-Allow-Origin', '*').header('Cache-Control', 'no-store')
    return success((await query(
      `SELECT ${productProjection} FROM products p JOIN categories c ON p.category_id = c.id
       WHERE p.is_active AND c.is_active ORDER BY p.created_at, p.id LIMIT 100`
    )).rows.map(row => ({ ...row, salePrice: row.sale_price, stockQuantity: row.stock_quantity })))
  })

  async function allowCheckout(request, reply) {
    const origin = request.headers.origin
    if (origin && origin !== appOrigin) throw fail('Use the local Flutter storefront', 403)
    reply.header('Access-Control-Allow-Origin', appOrigin)
      .header('Vary', 'Origin').header('Access-Control-Allow-Headers', 'Content-Type')
      .header('Access-Control-Allow-Methods', 'POST, OPTIONS')
  }

  for (const path of ['/api/v1/checkout/quote', '/api/v1/checkout/orders']) {
    app.options(path, async (request, reply) => {
      await allowCheckout(request, reply)
      return reply.code(204).send()
    })
  }
  app.post('/api/v1/checkout/quote', {
    onRequest: allowCheckout,
    schema: { body: { type: 'object', required: ['items'], properties: { items: cartItems } } },
  }, async request => success(await inspect({ query }, normalizedLines(request.body.items), false)))

  app.post('/api/v1/checkout/orders', {
    onRequest: allowCheckout,
    schema: { body: { type: 'object', required: ['items', 'request_id', 'quoted_total'],
      properties: { items: cartItems, request_id: uuid, quoted_total: { type: 'number', minimum: 0 } } } },
  }, async (request, reply) => {
    const result = await place(request.body.items, request.body.request_id, request.body.quoted_total)
    return reply.code(result.created ? 201 : 200).send(success(result.order, 'Demo order placed'))
  })

  app.get('/api/v1/admin/commerce/products', admin, async () => success((await query(
    `SELECT ${productProjection} FROM products p JOIN categories c ON p.category_id = c.id
     WHERE p.is_active ORDER BY p.created_at DESC, p.id LIMIT 100`
  )).rows))

  app.post('/api/v1/admin/commerce/products', {
    ...admin,
    schema: { body: { type: 'object', required: ['name', 'price', 'unit', 'stock', 'category'],
      properties: {
        name: { type: 'string', minLength: 1, maxLength: 100 },
        price: { type: 'number', minimum: 0.01, maximum: 100000 },
        unit: { type: 'string', minLength: 1, maxLength: 20 },
        stock: { type: 'integer', minimum: 0, maximum: 100000 },
        category: { type: 'string', enum: ['produce', 'dairy', 'pantry', 'snacks'] },
        image: { type: 'string', maxLength: 100 },
      },
    } },
  }, async (request, reply) => {
    const { name, price, stock, unit, category, image } = request.body
    if (!name.trim() || !unit.trim()) throw fail('Enter a product name and unit', 422)
    if (image && (!mediaId(image) || !(await query('SELECT 1 FROM theme_bundle_media WHERE id = $1', [mediaId(image)])).rowCount)) {
      throw fail('Upload the product photo before saving', 422)
    }
    const { rows: [product] } = await query(
      `INSERT INTO products(name, slug, price, stock_quantity, unit, category_id, thumbnail_url)
       SELECT $1, $2, $3, $4, $5, id, $6 FROM categories WHERE slug = $7 AND is_active
       RETURNING id, name`, [name.trim(), randomUUID(), round(price), stock, unit.trim(), image ?? null, category]
    )
    if (!product) throw fail('The selected category is unavailable', 422)
    return reply.code(201).send(success(product, 'Product added'))
  })

  app.get('/api/v1/admin/commerce/orders', admin, async () => success((await query(
    'SELECT * FROM orders WHERE checkout_request_id IS NOT NULL ORDER BY created_at DESC, id LIMIT 100'
  )).rows.map(orderView)))
}
