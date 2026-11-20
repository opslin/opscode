import { createServer } from 'node:http'
import { createReadStream } from 'node:fs'
import { stat } from 'node:fs/promises'
import { dirname, extname, resolve, sep } from 'node:path'
import { fileURLToPath } from 'node:url'
import { api, manifest, publish } from './demo-api.mjs'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const port = Number(process.env.VELO_DEMO_PORT || 5010)
const origin = `http://127.0.0.1:${port}`
const mime = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.mjs': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg', '.webp': 'image/webp', '.svg': 'image/svg+xml', '.ttf': 'font/ttf', '.otf': 'font/otf' }
const json = (res, status, data) => {
  res.writeHead(status, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' })
  res.end(JSON.stringify(data))
}
async function body(req) {
  const chunks = []
  let length = 0
  for await (const bytes of req) {
    length += bytes.length
    if (length > 64 * 1024) throw new Error('Request too large')
    chunks.push(bytes)
  }
  return length ? JSON.parse(Buffer.concat(chunks).toString()) : {}
}
async function serve(req, res, directory, name) {
  const folder = resolve(root, directory)
  const file = resolve(folder, name || 'index.html')
  if (!file.startsWith(folder + sep)) return false
  const info = await stat(file).catch(() => null)
  if (!info?.isFile()) return false
  res.writeHead(200, { 'content-type': mime[extname(file)] ?? 'application/octet-stream',
    'content-length': info.size, 'x-content-type-options': 'nosniff', 'cache-control': 'no-cache' })
  if (req.method === 'HEAD') res.end()
  else createReadStream(file).pipe(res)
  return true
}

createServer(async (req, res) => {
  try {
    const url = new URL(req.url, origin)
    const path = decodeURIComponent(url.pathname)
    const method = req.method
    if (req.headers.origin && req.headers.origin !== origin) return json(res, 403, { message: 'Use the local demo address' })
    if (path === '/demo/state' && method === 'GET') return json(res, 200, manifest(origin))
    if (path === '/demo/publish' && method === 'POST') {
      const updated = publish((await body(req)).title)
      return json(res, updated ? 200 : 400, updated ?? { message: 'Enter a title of 1–100 characters' })
    }
    if (path.startsWith('/api/v1/')) {
      const data = api(method, url, method === 'GET' ? {} : await body(req), origin)
      process.stdout.write(`${data ? '200' : '404'} ${method} ${path}\n`)
      return json(res, data ? 200 : 404, data ?? { success: false, message: 'Demo operation unavailable' })
    }
    for (const role of ['customer', 'vendor']) {
      if (path === `/${role}`) { res.writeHead(302, { location: `/${role}/` }); return res.end() }
      if (path.startsWith(`/${role}/`) && await serve(req, res, `${role}/build/web`, path.slice(role.length + 2))) return
    }
    if (path.startsWith('/uploads/') && await serve(req, res, 'service/media', path.slice(9))) return
    if (path.startsWith('/uploads/products/')) {
      const name = path.split('/').at(-1)
      const fallback = /headphone|tune/.test(name) ? 'headphones' : /buds|pods/.test(name) ? 'earbuds'
        : /power-bank/.test(name) ? 'powerbank' : /charge|adapter/.test(name) ? 'charger'
        : /watch/.test(name) ? 'smartwatch' : /laptop|macbook/.test(name) ? 'laptop'
        : /pad|tab/.test(name) ? 'tablets' : 'smartphones'
      if (await serve(req, res, 'vendor/assets/categories', fallback + '.png')) return
    }
    if ((method === 'GET' || method === 'HEAD') && await serve(req, res, 'dashboard', path.slice(1))) return
    json(res, 404, { message: 'Local demo resource unavailable' })
  } catch (error) {
    console.error(error.message)
    if (!res.headersSent) json(res, 400, { message: 'Invalid demo request' })
    else res.end()
  }
}).listen(port, '127.0.0.1', () => console.log(`Velo Devices demo at ${origin}/`))
