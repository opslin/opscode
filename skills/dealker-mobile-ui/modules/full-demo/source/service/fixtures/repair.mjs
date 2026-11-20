import { brand, catalog, seedMedia } from './catalog.mjs'

const issueNames = { SCREEN: 'Screen replacement', BATTERY: 'Battery replacement', CHARGING: 'Charging port', CAMERA: 'Camera', AUDIO: 'Speaker and microphone', WATER_DAMAGE: 'Water damage', SOFTWARE: 'Software diagnostics' }
const issues = Object.entries(issueNames).map(([key, label]) => ({ key, code: key, label, name: label }))
const deadline = () => new Date(Date.now() + 86400000).toISOString()

export function repairs(origin) {
  const phones = [['OnePlus', 'OnePlus 11', 3], ['Samsung', 'Galaxy S24', 4], ['Apple', 'iPhone 15', 5]]
  const products = catalog(origin)
  const devices = [{ id: 'repair-phone', brand: 'OnePlus', model: 'OnePlus 11', category: 'PHONE',
    issueKeys: ['SCREEN'], issues: ['SCREEN'], problemCategories: ['SCREEN'], problemDescription: 'Cracked screen' }]
  const base = {
    id: 'demo-repair', code: 'VD-R1042', flow: 'MARKETPLACE', status: 'OPEN', createdAt: new Date().toISOString(),
    offerCount: 2, offersCloseAt: deadline(), items: devices, deviceCount: 1, firstDevice: 'OnePlus 11',
    device: 'OnePlus 11', location: { pincode: '560001' }, description: 'Cracked screen after a drop',
    money: { total: 3499 }, media: [], payments: [], quotes: [],
  }
  const offer = (id, shopName, total, rating) => ({
    id, total, subtotal: total, taxAmount: 0, status: 'OPEN', validUntil: deadline(),
    shopVisit: true, pickupDelivery: true, warrantyDays: 90, estDaysMin: 1, estDaysMax: 2,
    distanceKm: rating > 4.7 ? 1.2 : 2.4, note: 'Includes parts, fitting and post-repair diagnostics.',
    lines: [{ kind: 'PART', itemId: 'repair-phone', problemCategory: 'SCREEN', description: 'Display assembly', qty: 1, unitPrice: total }],
    vendor: { id: 'demo-shop', shopName, name: shopName, address: '18 Lakeview Road, Bengaluru', rating, ratingCount: 42 },
  })
  const list = [
    base,
    { ...base, id: 'demo-repair-tracking', code: 'VD-R1022', status: 'IN_REPAIR', fulfilment: 'PICKUP_DELIVERY', selectedOfferId: 'demo-offer' },
    { ...base, id: 'demo-repair-complete', code: 'VD-R1011', status: 'COMPLETED', fulfilment: 'SHOP_VISIT', selectedOfferId: 'demo-offer' },
  ]
  const offers = { requestId: base.id, status: base.status, offersCloseAt: base.offersCloseAt, lowestTotal: 3499, offers: [offer('demo-offer', brand + ' Service', 3499, 4.9), offer('demo-offer-two', 'Lakeview Repairs', 3899, 4.6)] }
  const tracking = {
    ...list[1], serviceCenter: { name: brand + ' Service', technician: 'Maya' },
    steps: ['REQUESTED', 'BOOKED', 'PICKED_UP', 'IN_REPAIR', 'READY', 'DELIVERED'].map((key, index) => ({
      key, label: ['Requested', 'Booked', 'Picked up', 'In repair', 'Ready', 'Delivered'][index],
      done: index < 4, current: index === 3, at: index < 4 ? base.createdAt : null,
    })),
  }
  return {
    config: { settings: { marketplace: true, marketplaceEnabled: true, diagnosticFee: 149, searchRadiusKm: 10 }, issues },
    brands: phones.map(([name]) => ({ name, logoUrl: seedMedia(origin, 'tab-smartphones.png') })),
    models: phones.map(([brand, name, index]) => ({
      name, model: name, category: 'Smartphone', brand, imageUrl: products[index].thumbnail_url,
    })),
    list, offers, tracking,
  }
}
