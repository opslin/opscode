// Adapted from Bakaloo's orders.repository.js for the original 004_orders schema.
export class OrdersRepository {
  async create(client, order, items) {
    const { rows: [row] } = await client.query(
      `INSERT INTO orders (
        order_number, user_id, status, items, subtotal, discount_amount,
        delivery_fee, total_amount, payment_method, payment_status,
        delivery_address, checkout_request_id, checkout_fingerprint
      ) VALUES ($1,$2,'PENDING',$3,$4,$5,$6,$7,'COD','PENDING',$8,$9,$10)
      RETURNING *`,
      [order.number, order.userId, JSON.stringify(items), order.bill.itemsSubtotal,
       order.bill.itemDiscount, order.bill.deliveryFee, order.bill.totalPayable,
       JSON.stringify(order.address), order.requestId, order.fingerprint]
    )

    for (const item of items) {
      await client.query(
        `INSERT INTO order_items (order_id, product_id, name, price, quantity, unit, total)
         VALUES ($1,$2,$3,$4,$5,$6,$7)`,
        [row.id, item.productId, item.name, item.price, item.quantity, item.unit, item.total]
      )
    }
    return row
  }

  async decrementStock(client, items) {
    for (const item of items) {
      const { rowCount } = await client.query(
        `UPDATE products SET stock_quantity = stock_quantity - $1, total_sold = total_sold + $1,
                updated_at = NOW()
         WHERE id = $2 AND stock_quantity >= $1`,
        [item.quantity, item.productId]
      )
      if (rowCount === 0) {
        throw Object.assign(new Error(`Insufficient stock for product "${item.name}"`), { statusCode: 409 })
      }
    }
  }

  async generateOrderNumber(client) {
    const today = new Date().toISOString().slice(0, 10).replace(/-/g, '')
    const { rows: [{ next }] } = await client.query("SELECT nextval('theme_bundle_order_number') AS next")
    return `FB-${today}-${Number(next).toString(36).padStart(4, '0').toUpperCase()}`
  }
}
