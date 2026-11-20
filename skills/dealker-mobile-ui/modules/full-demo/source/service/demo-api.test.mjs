import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'
import { test } from 'node:test'
import { api, manifest, publish } from './demo-api.mjs'

const origin = 'http://127.0.0.1:5010'
const index = JSON.parse(readFileSync(new URL('../dashboard/index.json', import.meta.url)))

function request(path, method = 'GET', body = {}) {
  const response = api(method, new URL(origin + '/api/v1' + path), body, origin)
  assert.equal(response?.success, true, path)
  return response.data
}

test('homepage fixtures cover the indexed renderers and accept publication', () => {
  const data = manifest(origin)
  assert.deepEqual(
    data.sections.map(section => section.section_type).sort(),
    Object.keys(index.sections).sort(),
  )
  assert.equal(publish('Demo publication').revision, 1)
  assert.equal(manifest(origin).sections.find(section => section.id === 'text_header').config.text, 'Demo publication')
})

test('product and store images resolve to bundled media files', () => {
  const urls = [
    ...request('/products').map(product => product.thumbnail_url),
    ...request('/theme/stores').stores.map(store => store.icon_url),
    ...request('/banners').map(banner => banner.image_url),
  ]
  for (const url of urls) {
    const image = new URL(url)
    assert.equal(image.origin, origin)
    assert.ok(existsSync(new URL('./media/' + image.pathname.slice('/uploads/'.length), import.meta.url)), url)
  }
})

test('a customer repair reaches the vendor and the quote can be booked', () => {
  const repair = request('/repairs', 'POST', {
    items: [{ brand: 'OnePlus', model: 'OnePlus 11', problemCategories: ['SCREEN'] }],
  })
  assert.ok(request('/manage/repairs/market/incoming').items.some(item => item.id === repair.id))
  const offer = request('/manage/repairs/market/incoming/' + repair.id + '/offer', 'POST', {
    lines: [{ qty: 1, unitPrice: 3150 }],
  })
  assert.equal(request('/repairs/' + repair.id + '/offers').offers[0].id, offer.id)
  const booked = request('/repairs/' + repair.id + '/offers/' + offer.id + '/select', 'POST', { fulfilment: 'SHOP_VISIT' })
  assert.equal(booked.status, 'BOOKED')
})

test('a customer cart can become an order in the vendor inbox', () => {
  const product = request('/products')[0]
  request('/cart/items', 'POST', { productId: product.id, quantity: 1 })
  const order = request('/orders', 'POST', { paymentMethod: 'COD' })
  assert.ok(request('/manage/orders').some(row => row.id === order.id))
  assert.equal(request('/seller-orders/' + order.id).items[0].product_name, product.name)
})
