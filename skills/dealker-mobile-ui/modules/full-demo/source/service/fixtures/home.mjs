import { brand, catalog, categories, seedMedia } from './catalog.mjs'

const storesList = [
  ['mobile', 'Mobile', 'store-mobile.png', 'banner-mobiles.png'],
  ['mobile_part', 'Mobile Parts', 'store-mobile-part.png', 'banner-parts.png'],
  ['accessories', 'Accessories', 'store-accessories.png', 'banner-accessories.png'],
  ['electronics', 'Electronics', 'store-electronics.png', 'banner-mobiles.png'],
]
export function stores(origin) {
  return storesList.map(([store_key, label, image]) => ({ store_key, label, icon_url: seedMedia(origin, image) }))
}

export function banners(origin, storeKey) {
  const item = storesList.find(([key]) => key === storeKey) ?? storesList[0]
  return [item[3], 'banner-accessories.png'].map((name, i) => ({
    id: `banner-${i}`, title: i === 0 ? brand : 'Accessories', image_url: seedMedia(origin, name),
    link_type: 'CATEGORY', link_value: i === 0 ? 'phones' : 'audio', sort_order: i,
  }))
}

export function storeTabs(origin, storeKey) {
  const items = categories(origin).slice(1)
  const tabs = [{ id: 'all', name: 'All', image_url: seedMedia(origin, 'tab-all.png') }, ...items]
  return {
    store_key: storeKey, delivery_eta_minutes: 25,
    tabs: tabs.map(({ id, name, image_url }, tab_order) => ({
      store_key: storeKey, tab_id: id, tab_key: id, tab_label: name, tab_icon_url: image_url,
      tab_order, is_default: id === 'all', tab_text_color: '#151226',
      theme_data: {
        meta: { seasonLabel: brand },
        sections: {
          searchZone: { searchHints: ['smartphones', 'headphones', 'power banks'], sellBoxImageUrl: seedMedia(origin, 'store-mobile.png') },
          feeStrip: { visible: true },
          bankOffers: { bannerImageUrls: [] },
        },
      },
    })),
  }
}

export function homepage(origin, storeKey = 'mobile', tabKey = 'all') {
  const products = catalog(origin)
  const cats = categories(origin).slice(1)
  const hero = banners(origin, storeKey)
  const select = id => products.filter(p => p.category_id === id)
  const priceCaps = ['₹55,000', '₹25,000', '₹2,000', '₹20,000']
  const tabs = cats.slice(0, 4).map((c, i) => ({
    label: c.id === 'phones' ? 'Phones' : c.name,
    sub_label: priceCaps[i], price_text: priceCaps[i],
    category_ids: [c.id], category_id: c.id, image_url: c.image_url, header_left_url: c.image_url,
    header_right_url: products[(i + 1) % products.length].thumbnail_url, products: select(c.id),
    tiles: cats.slice(0, 4).map(a => ({ title: a.name, label: a.name, image_url: a.image_url, category_id: a.id })),
    grid: cats.map(a => ({ title: a.name, label: a.name, image_url: a.image_url, category_id: a.id })),
    grid_title: 'Shop by category',
    chips: cats.map(a => ({ label: a.name, image_url: a.image_url, category_id: a.id })),
  }))
  const featured = tabKey === 'all' ? products : select(tabKey)
  const rows = [
    ['promo_carousel', { banner_source: 'custom', images: hero.map(b => b.image_url), auto_scroll: false }],
    ['fee_strip', { visible: true, title: 'Delivery benefits', lines: ['Verified sellers', 'Simple returns', 'Local delivery'] }],
    ['category_hub', { title: 'Shop by category', tabs }],
    ['seasonal_mosaic', {
      title: 'The upgrade edit', layout_variant: 'hero_plus_four',
      hero_tile: { title: 'The upgrade edit', image_url: seedMedia(origin, 'deal-zone.png') },
      mini_tiles: tabs.map(t => ({ title: t.label, image_url: t.image_url, action: { type: 'category', value: t.category_id } })),
    }],
    ['round_category_icons', { title: 'Quick categories', items: cats.map(c => ({ category_id: c.id, label: c.name, image_url: c.image_url })) }],
    ['price_sale', { title: 'Electronics sale', subtitle: 'Shop deals under', tabs }],
    ['steal_deals', { title: 'Steal deals', tabs }],
    ['live_auction', {}],
    ['deal_of_day', { title: 'Deal of the day' }],
    ['banner_rail', { title: 'More from Velo Devices', header_image_url: hero[1].image_url }],
    ['category_product_grid', { title: 'Recommended devices', columns: 2 }],
    ['product_carousel', { title: 'New arrivals' }],
    ['trending_products', { title: 'Trending near you' }],
    ['collection_showcase', { title: 'Explore collections', tabs }],
    ['brand_spotlight', { title: brand, image_url: hero[0].image_url, brand_name: brand }],
    ['price_shop', { title: 'Shop by price', tabs }],
    ['top_brands', { title: 'Top brands', cards: [
      { brand_name: 'Apple', image_url: products[2].thumbnail_url, category_id: 'phones' },
      { brand_name: 'Samsung', image_url: products[4].thumbnail_url, category_id: 'phones' },
      { brand_name: 'Sony', image_url: products[13].thumbnail_url, category_id: 'audio' },
    ] }],
    ['oval_spotlight', { title: 'The device spotlight' }],
    ['category_deals', { title: 'Category deals', tabs }],
    ['shops_nearby', { title: 'Shops nearby', visible: true }],
    ['arched_product_showcase', { title: 'Top picks', product_layout: 'horizontal_scroll' }],
    ['recent_recommended', { title: 'Recommended for you' }],
    ['animated_banner', { image_url: hero[0].image_url, height: 140 }],
    ['bank_offers', { image_urls: [hero[1].image_url] }],
    ['custom_banner', { image_url: hero[1].image_url, aspect_ratio: '16:6' }],
    ['text_header', { text: 'Explore more at Velo Devices', color: '#20152E', font_size: 20 }],
    ['spacer', { height: 24 }],
  ]
  const sections = rows.map(([type, config], index) => ({
    id: type, section_type: type, sort_order: index, visible: true, config,
    products: (featured.length ? featured : products).filter(p => p.stock_quantity > 0).slice(0, type === 'deal_of_day' ? 1 : 8),
  }))
  return { store_key: storeKey, tab_key: tabKey, sections }
}
