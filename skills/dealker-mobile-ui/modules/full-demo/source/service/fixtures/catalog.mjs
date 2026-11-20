import { existsSync, readFileSync } from 'node:fs'

const rows = JSON.parse(readFileSync(new URL('./media-source.json', import.meta.url)))
const groups = [
  ['phones', 'Smartphones', 'tab-smartphones.png'],
  ['audio', 'Audio', 'tab-audio.png'],
  ['charging', 'Charging', 'tab-chargers.png'],
  ['tablets', 'Tablets', 'tab-laptops.png'],
  ['wearables', 'Wearables', 'tab-wearables.png'],
  ['cases', 'Cases', 'tab-cases.png'],
]
const productsGroup = [1,0,0,0,0,0,2,4,2,1,3,3,1,1,0,5]
const names = [
  'Buds T300 Wireless Earbuds', 'Note 13 Pro · Fusion Purple', 'iPhone 12 · Blue',
  'OnePlus 11 · Titan Black', 'Galaxy S24 · Onyx Black', 'iPhone 15 · Blue',
  'MagSafe Power Bank · 10,000 mAh', 'Wave Call Smartwatch', 'USB-C Wall Adapter · 20 W',
  'Airdopes Wireless Earbuds', 'Pad SE · Graphite Grey', 'Galaxy Tab A9+ · 5G',
  'Flip 6 Portable Speaker', 'WH-1000XM5 Headphones', 'Galaxy Z Flip5 · Mint',
  'Ultra Hybrid Clear Case',
]
export const brand = 'Velo Devices'
export const customer = { id: 'demo-customer', role: 'CUSTOMER', name: 'Asha Patel', phone: '0000000000', email: 'asha@example.test' }
export const address = {
  id: 'demo-address', label: 'Home', line1: '18 Lakeview Road', address_line1: '18 Lakeview Road',
  addressLine1: '18 Lakeview Road', house_number: '18', city: 'Bengaluru', state: 'Karnataka',
  postal_code: '560001', pincode: '560001', latitude: 12.9716, longitude: 77.5946,
  is_default: true, isDefault: true, contact_name: customer.name, contact_phone: customer.phone,
}
export const media = (origin, folder, name) => `${origin}/uploads/${folder}/${name}`
export const seedMedia = (origin, name) => media(origin, 'home', name)

export function catalog(origin) {
  return rows.map((raw, index) => {
    const [category, categoryName, fallback] = groups[productsGroup[index]]
    const file = new URL(raw.thumbnail_url).pathname.split('/').at(-1)
    const image = existsSync(new URL(`../media/products/${file}`, import.meta.url))
      ? media(origin, 'products', file) : seedMedia(origin, fallback)
    const id = raw.id
    return {
      id, slug: `velo-${index + 1}`, name: names[index], price: Number(raw.price) || 1999,
      sale_price: raw.sale_price ? Number(raw.sale_price) : null,
      wholesale_price: Number(raw.wholesale_price) || Math.round(Number(raw.sale_price ?? raw.price) * .82),
      stock_quantity: index === 15 ? 0 : 12 + index, stock: index === 15 ? 0 : 12 + index,
      unit: '1 unit', condition: index === 3 ? 'USED' : 'NEW',
      battery_health: index === 3 ? 94 : null, category_id: category, category_name: categoryName,
      thumbnail_url: image, images: [image], image_url: image, is_active: true, is_featured: index < 6,
      avg_rating: 4.7, rating_count: 24 + index * 2, vendor_name: brand, sold_by: brand,
      return_policy: '7_day', display_delivery_minutes: 25, is_authentic: true,
      description: `${names[index]} from the Velo Devices demo catalog.`,
      tags: [category], total_sold: 30 + index, minimum_order_quantity: 3, moq: 3,
      seller: { id: 'demo-shop', name: brand, city: 'Bengaluru', rating: 4.8, reviews: 38 },
    }
  })
}

export function categories(origin) {
  return [
    { id: 'electronics', name: 'Electronics', image_url: seedMedia(origin, 'store-electronics.png'), parent_id: null, product_count: rows.length, is_active: true, sort_order: 0 },
    ...groups.map(([id, name, image], i) => ({
      id, name, image_url: seedMedia(origin, image), parent_id: 'electronics', product_count: productsGroup.filter(g => g === i).length,
      is_active: true, sort_order: i + 1,
    })),
  ]
}

export function shop(origin) {
  return {
    id: 'demo-shop', name: brand, vendor_name: brand, city: 'Bengaluru',
    rating: 4.8, rating_count: 38, product_count: rows.length, follower_count: 62, is_verified: true,
    address_line1: '18 Lakeview Road', logo_url: seedMedia(origin, 'store-electronics.png'),
    banner_url: seedMedia(origin, 'banner-mobiles.png'), categories: categories(origin), address: '18 Lakeview Road, Bengaluru',
  }
}
