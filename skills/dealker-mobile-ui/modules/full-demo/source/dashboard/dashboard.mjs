const index = await (await fetch('/index.json')).json()
const catalog = await (await fetch('/api/v1/products')).json()
const firstProduct = catalog.data[0].id
const buttons = ['customer', 'vendor', 'sections', 'map']
const status = document.querySelector('#status')
const listing = document.querySelector('#listing')
const filter = document.querySelector('#filter')
const heading = document.querySelector('#heading')
const frame = document.querySelector('#frame')
const link = document.querySelector('#fullscreen')
const metadata = document.querySelector('#metadata')
let mode = 'customer'
let current = { label: 'Customer Home', role: 'customer', example: '/home', source: 'customer/lib/features/home/presentation/screens/home_screen.dart' }

const titleCase = text => text.replaceAll('_', ' ').replace(/\b\w/g, ch => ch.toUpperCase())
const text = (tag, value) => Object.assign(document.createElement(tag), { textContent: value })
function details(entries) {
  metadata.replaceChildren()
  for (const [label,value] of entries) {
    metadata.append(text('dt', label), text('dd', value))
  }
}
function load(row, refresh = false) {
  const route = row.example.replace('DEMO_FIRST_PRODUCT', firstProduct)
  const url = `/${row.role}/${refresh ? '?revision=' + Date.now() : ''}#${route}`
  current = row
  document.querySelector('#title').textContent = row.label
  document.querySelector('#route').textContent = route
  frame.title = `Flutter ${row.role} · ${row.label}`
  frame.src = url
  link.href = url
  details([['Role', titleCase(row.role)], ['Flutter source', row.source], ['Route', row.route || route]])
}
function area(key, item) {
  details([
    ['Module area', titleCase(key)],
    ['Flutter source', item.flutter.join(' · ')],
    ['Original backend', item.backend.join(' · ')],
    ['Original dashboard', item.dashboard.join(' · ')],
    ['Local demo data', item.fixture],
  ])
}
function option(row) {
  const button = text('button', '')
  button.type = 'button'
  button.className = 'row'
  button.append(text('strong', row.label), text('code', row.route))
  button.setAttribute('aria-current', String(current.label === row.label && current.role === row.role))
  button.addEventListener('click', () => {
    if (row.area) area(row.area, index.areas[row.area])
    else load(row)
    for (const other of listing.querySelectorAll('.row')) other.setAttribute('aria-current', String(other === button))
  })
  return button
}
function draw() {
  for (const id of buttons) document.getElementById(id).setAttribute('aria-pressed', String(id === mode))
  const q = filter.value.toLowerCase().trim()
  let rows
  if (mode === 'sections') {
    const renderers = Object.entries(index.sections).map(([key, info]) => ({
      label: titleCase(key), route: key, example: '/demo/section/' + key,
      role: 'customer', source: 'customer/' + info.registry + ' · ' + info.builder,
    }))
    const slots = Object.entries(index.home_slots).flatMap(([role, slots]) =>
      slots.map(([label, source]) => ({label, route: role + ' home', example: '/home', role, source})))
    rows = [...slots, ...renderers]
  } else if (mode === 'map') {
    rows = Object.keys(index.areas).map(key => ({ label: titleCase(key), route: index.areas[key].fixture, area: key }))
  } else {
    rows = index.roles[mode].map(row => ({ ...row, role: mode }))
  }
  rows = rows.filter(row => (row.label + ' ' + row.route).toLowerCase().includes(q))
  listing.replaceChildren()
  if (!rows.length) listing.append(text('p', 'No matching screens.'))
  if (mode === 'sections' || mode === 'map' || q) {
    listing.append(...rows.map(option))
    return
  }
  const groups = new Map()
  for (const row of rows) {
    if (!groups.has(row.group)) groups.set(row.group, [])
    groups.get(row.group).push(row)
  }
  const preferred = ['home', 'categories', 'cart', 'repair', 'repairs', 'wholesale', 'products', 'orders']
  const keys = [...preferred.filter(key => groups.has(key)), ...[...groups.keys()].filter(key => !preferred.includes(key))]
  for (const key of keys) {
    const group = document.createElement('details')
    group.open = preferred.includes(key)
    group.append(text('summary', key.replaceAll('-', ' ')), ...groups.get(key).map(option))
    listing.append(group)
  }
}
for (const id of buttons) document.getElementById(id).addEventListener('click', () => {
  mode = id
  filter.value = ''
  draw()
  if (id === 'customer' || id === 'vendor') load({ ...index.roles[id].find(row => row.route === '/home'), role: id })
})
filter.addEventListener('input', draw)
document.querySelector('#publish').addEventListener('submit', async event => {
  event.preventDefault()
  status.textContent = 'Publishing…'
  try {
    const response = await fetch('/demo/publish', { method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ title: heading.value }) })
    const result = await response.json()
    if (!response.ok) throw Error(result.message)
    status.textContent = `Published revision ${result.revision}`
    load({ label: 'Text Header', role: 'customer', example: '/demo/section/text_header', source: 'customer/lib/features/home/presentation/widgets/text_header_section.dart' }, true)
  } catch (error) {
    status.textContent = error.message
  }
})
const draft = await (await fetch('/demo/state')).json()
heading.value = draft.sections.find(section => section.id === 'text_header').config.text
draw()
load(current)
