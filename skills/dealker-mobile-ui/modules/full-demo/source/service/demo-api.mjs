import { brand, customer, address, catalog, categories, seedMedia, shop } from './fixtures/catalog.mjs'
import { stores, storeTabs, banners, homepage } from './fixtures/home.mjs'
import { repairs } from './fixtures/repair.mjs'

const cart = new Map()
const wishlist = new Set()
const orders = []
const repairChanges = new Map()
const vendorOffers = new Map()
let storeSettings = { autoAcceptOrders: false, pickup: true, notificationEmail: 'orders@example.test' }
let publication = null
let revision = 0

export function manifest(origin, storeKey = 'mobile', tabKey = 'all') {
  const data = homepage(origin, storeKey, tabKey)
  return {
    ...data,
    revision,
    sections: data.sections.map(section => section.id === 'text_header' && publication
      ? { ...section, config: { ...section.config, text: publication } }
      : section),
  }
}

export function publish(text) {
  if (typeof text !== 'string' || !text.trim() || text.trim().length > 100) return null
  publication = text.trim()
  revision++
  return { title: publication, revision }
}

const searchable = (product, q) => product.name.toLowerCase().includes(q.toLowerCase())
const pagination = n => ({ page: 1, limit: 100, total: n, totalPages: 1, total_pages: 1, hasMore: false })
const okay = data => ({ success: true, message: 'OK', data, ...(Array.isArray(data) ? { pagination: pagination(data.length) } : {}) })

function cartView(products) {
  const items = [...cart].flatMap(([id, quantity]) => {
    const p = products.find(product => product.id === id)
    return p ? [{
      productId: id, name: p.name, price: p.price, salePrice: p.sale_price,
      quantity, lineTotal: quantity * (p.sale_price || p.price), thumbnailUrl: p.thumbnail_url,
      stockQuantity: p.stock_quantity, unit: p.unit, shopId: 'demo-shop', shopName: brand,
      categoryId: p.category_id, displayDeliveryMinutes: 25,
    }] : []
  })
  return { items, count: items.reduce((n, p) => n + p.quantity, 0), subtotal: items.reduce((n,p) => n + p.lineTotal,0) }
}

export function api(method, url, body, origin) {
  const path = url.pathname.replace(/^\/api\/v1/, '')
  const query = url.searchParams
  const storeKey = query.get('store_key') || query.get('storeKey') || 'mobile'
  const products = catalog(origin)
  const cats = categories(origin)
  const r = repairs(origin)
  let match
  const auction = {
    id: 'demo-auction', title: 'Open-box iPhone 15', description: 'Inspected demo lot with accessories.',
    status: 'LIVE', tab: 'live', starting_price: 12000, current_bid: 14800, bid_count: 7,
    image_url: products[5].thumbnail_url, cover_image_url: products[5].thumbnail_url,
    images: [products[5].thumbnail_url], end_at: new Date(Date.now() + 5400000).toISOString(),
    ends_at: new Date(Date.now() + 5400000).toISOString(), starts_at: new Date(Date.now() - 3600000).toISOString(),
    vendor_name: brand, seller_name: brand, condition: 'OPEN_BOX', reserve_met: true,
  }
  const seededOrder = {
    id: 'demo-order', orderNumber: 'VD-1048', order_number: 'VD-1048',
    status: 'DELIVERED', totalAmount: 1499, total_amount: 1499,
    createdAt: new Date().toISOString(), created_at: new Date().toISOString(),
    paymentMethod: 'COD', paymentStatus: 'PAID', deliveryAddress: address,
    items: [orderLine(products[0], 1, 1499)], deliveryFee: 0, subtotal: 1499,
  }
  if (path === '/theme/stores') return okay({ stores: stores(origin) })
  if (path === '/theme/tabs') return okay(storeTabs(origin, storeKey))
  if ((match = path.match(/^\/theme\/tabs\/([^/]+)\/sections$/))) return okay(manifest(origin, storeKey, match[1]))
  if ((match = path.match(/^\/theme\/tabs\/([^/]+)\/home$/))) return okay({
    tab_key: match[1], store_key: storeKey, products, banners: banners(origin, storeKey),
    featured: products.slice(0,8), new_arrivals: products.slice(4), deals: products.filter(p => p.sale_price),
  })
  if (path === '/theme/active') return okay(storeTabs(origin, storeKey).tabs[0].theme_data)
  if (path === '/banners') return okay(banners(origin, storeKey))
  if (path === '/branding') return okay({ name: brand, app_name: brand, brand_name: brand })
  if (path === '/app/version-check') return okay({ update_required: false, force_update: false, update_available: false })
  if (path === '/users/me') return okay(customer)
  if (path === '/users/me/stats') return okay({ orders: 1, wishlist: wishlist.size, walletBalance: 5000 })
  if (path === '/auth/send-otp') return okay({ sent: true })
  if (path === '/auth/verify-otp') return okay({ user: customer, accessToken: 'local-demo', refreshToken: 'local-demo', access_token: 'local-demo', refresh_token: 'local-demo' })
  if (path === '/addresses' && method === 'GET') return okay([address])
  if (path === '/addresses/validate-pincode' || path === '/storefront/resolve-location') return okay({ serviceable: true, isValid: true, storefrontToken: 'local-demo', city: address.city })
  if (path === '/allocation/my-shops') return okay([])
  if (path === '/categories' || path === '/categories/admin') return okay(cats)
  if ((match = path.match(/^\/categories\/([^/]+)\/products$/))) return okay(match[1] === 'electronics' ? products : products.filter(p => p.category_id === match[1]))
  if ((match = path.match(/^\/categories\/([^/]+)$/))) return okay(cats.find(c => c.id === match[1]) ?? cats[0])
  if (path === '/products/search' || path === '/products') {
    const q = query.get('q') || query.get('search') || ''
    const group = query.get('category_id') || query.get('categoryId')
    return okay(products.filter(p => searchable(p, q) && (!group || group === 'electronics' || p.category_id === group)))
  }
  if (/^\/products\/(featured|new-arrivals|deals|price-drops|last-minute)$/.test(path)) return okay(products.slice(0,8))
  if ((match = path.match(/^\/products\/([^/]+)\/(related|pair-with)$/))) return okay(products.filter(p => p.id !== match[1]).slice(0,6))
  if ((match = path.match(/^\/products\/([^/]+)$/))) return okay(products.find(p => p.id === match[1] || p.slug === match[1]) ?? products[0])
  if (path === '/cart' && method === 'DELETE') cart.clear()
  if (path === '/cart') return okay(cartView(products))
  if (path === '/cart/items' && method === 'POST') {
    const id = body.productId ?? body.product_id
    const p = products.find(product => product.id === id)
    if (p?.stock_quantity) cart.set(id, Math.min(p.stock_quantity, (cart.get(id) ?? 0) + (Number(body.quantity) || 1)))
    return okay(cartView(products))
  }
  if ((match = path.match(/^\/cart\/items\/([^/]+)$/))) {
    if (method === 'DELETE' || body.quantity <= 0) cart.delete(match[1])
    else if (cart.has(match[1])) cart.set(match[1], Math.min(products.find(p => p.id === match[1]).stock_quantity, Number(body.quantity) || 1))
    return okay(cartView(products))
  }
  if (path === '/cart/summary') {
    const c = cartView(products)
    return okay({ ...c, itemsSubtotal: c.subtotal, itemTotal: c.subtotal, totalPayable: c.subtotal, total: c.subtotal,
      deliveryFee: 0, savings: 0, deliveryEstimate: { minutes: 25 }, fees: [], codEnabled: true, onlineEnabled: false })
  }
  if (path === '/cart/validate') return okay({ isValid: true, valid: true, items: [], issues: [] })
  if (path === '/cart/quick-add') return okay(products.slice(0,4))
  if (path === '/orders' && method === 'POST') {
    const c = cartView(products)
    const order = { ...seededOrder, id: `order-${orders.length + 1}`, orderNumber: `VD-${1050 + orders.length}`,
      status: 'CONFIRMED', paymentStatus: 'PENDING', totalAmount: c.subtotal, total_amount: c.subtotal,
      subtotal: c.subtotal, items: c.items.map(item => orderLine(products.find(product => product.id === item.productId), item.quantity, item.lineTotal)) }
    order.order_number = order.orderNumber
    orders.unshift(order)
    cart.clear()
    return okay(order)
  }
  if (path === '/orders' || path === '/orders/active') return okay(path.endsWith('active') ? orders : [...orders, seededOrder])
  if ((match = path.match(/^\/orders\/([^/]+)$/))) return okay(orders.find(o => o.id === match[1]) ?? seededOrder)
  if (path === '/wishlist') return okay({ items: products.filter(p => wishlist.has(p.id)).map(p => ({ ...p, productId: p.id, product: p })) })
  if (path === '/wishlist/items' && method === 'POST') { wishlist.add(body.productId ?? body.product_id); return okay({}) }
  if ((match = path.match(/^\/wishlist\/items\/([^/]+)$/))) { wishlist.delete(match[1]); return okay({}) }
  if (path === '/wallet') return okay({ balance: 5000, available: 5000, currency: 'INR' })
  if (path === '/settlements/summary') return okay({ available: 24850, pending: 4400, paid: 10200 })
  if (path === '/notifications') return okay({ notifications: [], unreadCount: 0 })
  if (path === '/refund-requests/policy') return okay({ window_days: 7, free_pickup: true, points: [
    { title: 'Seven-day window', text: 'Start a return from the order page within seven days of delivery.' },
    { title: 'Prepare your device', text: 'Keep the original accessories and packaging ready for pickup.' },
  ] })
  if (path === '/discovery/shops') return okay([shop(origin)])
  if (path === '/discovery/shops/demo-shop') return okay(shop(origin))
  if (path === '/discovery/shops/demo-shop/products') return okay(products)
  if (path === '/auctions') return { ...okay([auction]), server_time: new Date().toISOString() }
  if (path === '/auctions/watching' || path === '/auctions/mine') return okay([])
  if (path === '/auctions/demo-auction') return okay({ ...auction, auction, bids: [], listings: [products[5]] })
  if (path === '/repairs/config') return okay(r.config)
  if (path === '/repairs/catalogue/brands') return okay(r.brands)
  if (path === '/repairs/catalogue/models') return okay(r.models.filter(model =>
    (!query.get('brand') || model.brand === query.get('brand')) && searchable(model, query.get('q') || '')))
  if (path === '/repairs/devices/recent') return okay([])
  if (path === '/repairs/mine') return okay({ items: [...repairChanges.values(), ...r.list.filter(item => !repairChanges.has(item.id))] })
  if (path === '/repairs' && method === 'POST') {
    const id = `local-repair-${repairChanges.size + 1}`
    const items = (body.items ?? []).map((item, index) => ({...item, id: `${id}-device-${index + 1}`}))
    const repair = { ...r.list[0], ...body, id, code: `VD-R${1050 + repairChanges.size}`,
      items, firstDevice: items[0]?.model, deviceCount: items.length, createdAt: new Date().toISOString() }
    repairChanges.set(id, repair)
    return okay(repair)
  }
  if ((match = path.match(/^\/repairs\/([^/]+)\/offers(?:\/([^/]+)\/select)?$/))) {
    const id = match[1]
    if (match[2]) {
      const current = repairChanges.get(id) ?? r.list.find(item => item.id === id) ?? r.list[0]
      const selectedOffer = [...r.offers.offers, vendorOffers.get(id)].find(offer => offer?.id === match[2])
      const booking = { ...current, ...body, id, selectedOfferId: match[2], selectedOffer, status: 'BOOKED' }
      repairChanges.set(id, booking)
      return okay(booking)
    }
    const submitted = vendorOffers.get(id)
    const offers = [...(submitted ? [submitted] : []), ...r.offers.offers]
    return okay({ ...r.offers, requestId: id, offers, lowestTotal: Math.min(...offers.map(offer => offer.total)) })
  }
  if (/^\/repairs\/[^/]+\/tracking$/.test(path)) return okay(r.tracking)
  if (/^\/repairs\/[^/]+\/messages$/.test(path)) return okay({ items: [], messages: [] })
  if (/^\/repairs\/[^/]+\/pay$/.test(path)) return okay({ amount: 3499, walletBalance: 5000, walletEnabled: true })
  if ((match = path.match(/^\/repairs\/([^/]+)$/))) return okay(repairChanges.get(match[1]) ?? r.list.find(item => item.id === match[1]) ?? r.list[0])
  if (path === '/store/status') return okay({ isOpen: true, open: true })
  if (path === '/vendor/store/settings') {
    if (method === 'PUT') storeSettings = body
    return okay(storeSettings)
  }
  if (path === '/vendors/demo' || path === '/vendor/growth') return okay({
    id:'demo', name:brand, business_name:brand, shop_name:brand, is_verified:true, verified:true,
    address:address.addressLine1, latitude:address.latitude, longitude:address.longitude, lat:address.latitude, lng:address.longitude,
  })
  if (path === '/vendor/b2b/wholesale') {
    const q = query.get('search') ?? ''
    return { ...okay(products.filter(p => p.stock >= p.moq && searchable(p,q)).map(p => ({
      ...p, retail_price:p.sale_price || p.price, seller:{ ...p.seller, name:'Lakeview Distributor' }
    }))), facets: { brands:[], conditions:[] } }
  }
  if (path === '/vendor/b2b/wholesale/categories') return okay(cats.map(c => ({...c,count:c.product_count})))
  if ((match = path.match(/^\/vendor\/b2b\/wholesale\/([^/]+)$/))) {
    const p = products.find(item => item.id === match[1]) ?? products[0]
    return okay({ ...p, listing:p, product:p, retail_price:p.sale_price || p.price })
  }
  if (path === '/vendor/orders' || path === '/vendor/orders/mine') return okay({items:[seededOrder], total:1})
  if (path === '/vendor/orders/demo-order') return okay(seededOrder)
  if (path === '/manage/orders') {
    const rows = [...orders, seededOrder].map(order => ({
      id: order.id, number: order.orderNumber, kind: 'PRODUCT', status: order.status,
      stage: order.status === 'DELIVERED' ? 'DONE' : 'NEW',
      title: order.items[0]?.product_name, quantity: order.items.reduce((sum, item) => sum + item.quantity, 0),
      customer: customer.name, amount: order.totalAmount, payable: order.totalAmount,
      payment_status: order.paymentStatus, created_at: order.createdAt, thumbnail: order.items[0]?.thumbnail_url,
    }))
    const visible = rows.filter(row => {
      const tab = query.get('tab')
      const search = query.get('q')?.toLowerCase()
      return (!tab || tab === 'all' || tab === row.stage.toLowerCase()) &&
        (!search || [row.title, row.number, row.customer].some(value => value?.toLowerCase().includes(search)))
    })
    return { ...okay(visible), counts: { all: rows.length, new: orders.length, done: 1 }, types: { all: rows.length, product: rows.length } }
  }
  if ((match = path.match(/^\/seller-orders\/([^/]+)$/)) && method === 'GET') {
    const order = orders.find(order => order.id === match[1]) ?? seededOrder
    return okay({ ...order, seller_order_number: order.orderNumber, parent_order_number: order.orderNumber,
      payment_method: order.paymentMethod, payment_status: order.paymentStatus, delivery_address: address,
      item_subtotal: order.subtotal, payable_to_seller: order.totalAmount })
  }
  if (path === '/manage/repairs/market/incoming' || path === '/manage/repairs' || path.startsWith('/manage/repairs/')) {
    const device = { ...r.list[0].items[0], problemCategories:['SCREEN'], problemDescription:'Cracked screen' }
    const incoming = { ...r.list[0], customer:{ firstName:'Asha', name:customer.name, pincode:address.pincode },
      firstDevice:'OnePlus 11', items:[device], distanceKm:1.2, estimate:{total:3499,complete:true} }
    const asIncoming = repair => ({
      ...incoming, ...repair, customer: incoming.customer,
      items: (repair.items ?? incoming.items).map(item => ({
        ...item, problemCategories: item.problemCategories ?? item.issueKeys ?? ['SCREEN'],
      })),
      offer: vendorOffers.get(repair.id),
    })
    const job = { ...incoming, status:'IN_REPAIR', technician:'Maya', pickupAddress:address.addressLine1,
      money:{approvedTotal:3499,amountPaid:149,amountDue:3350},
      quotes:[{status:'APPROVED',lines:r.offers.offers[0].lines}] }
    if (path.endsWith('/market/incoming')) {
      const rows = [repairChanges.get(incoming.id) ?? incoming, ...[...repairChanges.values()].filter(row => row.id !== incoming.id)]
      const tab = query.get('tab')
      return okay({
        items: rows.filter(row => tab !== 'quoted' || vendorOffers.has(row.id)).map(asIncoming),
        counts: { all: rows.length, new: rows.length - vendorOffers.size, quoted: vendorOffers.size },
      })
    }
    if (path.endsWith('/suggested-quote')) return okay({lines:r.offers.offers[0].lines})
    if ((match = path.match(/\/market\/incoming\/([^/]+)\/offer$/))) {
      const id = match[1]
      if (method === 'DELETE') { vendorOffers.delete(id); return okay({}) }
      const lines = Array.isArray(body.lines) ? body.lines : []
      const subtotal = lines.reduce((sum, line) => sum + Number(line.qty || 1) * Number(line.unitPrice || 0), 0)
      const offer = {
        ...r.offers.offers[0], ...body, id: 'local-vendor-offer', lines,
        subtotal, total: Math.max(0, subtotal - Number(body.discount || 0)), status: 'OPEN',
      }
      vendorOffers.set(id, offer)
      return okay(offer)
    }
    if (path.endsWith('/market/services')) return okay([{
      id: 'screen-service', deviceCategory: 'Smartphone', brand: 'OnePlus', model: 'OnePlus 11',
      problemCategory: 'SCREEN', title: 'Display assembly', partsPrice: 2999, labourPrice: 500,
      estDaysMin: 1, estDaysMax: 2, warrantyDays: 90, pickupDelivery: true, isActive: true,
    }])
    if (path.endsWith('/market/profile')) return okay({acceptingRequests:true,activeServices:1})
    if (path.endsWith('/price-list')) return okay({items:[], services:[]})
    if (path.endsWith('/messages')) return okay({items:[], messages:[]})
    if (path === '/manage/repairs') return okay({items:[job]})
    const id = path.split('/').at(-1)
    return okay(path.includes('/market/') ? asIncoming(repairChanges.get(id) ?? incoming) : job)
  }
  const deal = { id:'demo-deal', name:'Velo launch offers', title:'Velo launch offers', status:'ACTIVE',
    description:'Feature a listing in the weekly electronics sale.', entries: [] }
  if (path === '/vendor/deals') return okay([deal])
  if (path === '/vendor/deals/demo-deal') return okay(deal)
  if (path === '/wholesale/products' || path === '/b2b/products' || path === '/marketplace/products') return okay({ items: products, products, total: products.length })
  if (path === '/checkout/payment-methods') return okay({ cod: true, online: false })
  if (['/purchase-limits/my-status','/notifications/preferences','/business-accounts/me','/exchange-requests/summary','/sell-requests/journey-config'].includes(path)) return okay({})
  if (method === 'GET') return okay([])
  return null
}

function orderLine(product, quantity, total) {
  return {
    product_id: product.id, productId: product.id, product_name: product.name, name: product.name,
    thumbnail_url: product.thumbnail_url, quantity, unit_price: total / quantity, subtotal: total,
  }
}
