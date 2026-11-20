import { createHash, timingSafeEqual } from 'node:crypto'
import multipart from '@fastify/multipart'
import Fastify from 'fastify'
import { pool, query } from './config/database.js'
import adminSectionRoutes from './modules/admin/sections/sections.routes.js'
import adminTabRoutes from './modules/admin/theme-tabs/theme-tabs.routes.js'
import { ThemesRepository } from './modules/admin/themes/themes.repository.js'
import publicThemeRoutes from './modules/themes/public.routes.js'
import { publishLayout } from './modules/themes/publication.js'
import requestContextPlugin from './plugins/requestContext.plugin.js'
import { error, success } from './utils/apiResponse.js'

const token = process.env.THEME_BUILDER_ADMIN_TOKEN
if (!token || token.length < 24) throw new Error('Set THEME_BUILDER_ADMIN_TOKEN to at least 24 characters')
const tokenDigest = createHash('sha256').update(`Bearer ${token}`).digest()
const editor = { id: '00000000-0000-4000-8000-000000000321', role: 'ADMIN' }

const app = Fastify({ logger: { level: process.env.LOG_LEVEL ?? 'warn' } })
app.decorateRequest('user', null)
app.decorate('authenticate', async request => {
  const value = createHash('sha256').update(request.headers.authorization ?? '').digest()
  if (!timingSafeEqual(value, tokenDigest)) {
    throw Object.assign(new Error('Local editor authorization required'), { statusCode: 401 })
  }
  request.user = editor
})
app.decorate('requireAdmin', async request => {
  if (request.user?.role !== 'ADMIN') throw Object.assign(new Error('Admin required'), { statusCode: 403 })
})
await app.register(requestContextPlugin)
await app.register(multipart, { limits: { files: 1, fileSize: 5 * 1024 * 1024, fields: 2, parts: 3 } })
await app.register(adminSectionRoutes, { prefix: '/api/v1/admin/sections' })
await app.register(adminTabRoutes, { prefix: '/api/v1/admin/theme-tabs' })
await app.register(publicThemeRoutes, { prefix: '/api/v1/theme' })
app.get('/health', async () => {
  await query('SELECT 1 FROM theme_bundle_publications LIMIT 1')
  return { ok: true }
})

const admin = { preHandler: app.authenticate }
const themes = new ThemesRepository()
app.get('/api/v1/admin/themes/tabs', admin, async () => success(await themes.findAllTabThemes()))
app.get('/api/v1/categories/admin', admin, async () =>
  success((await query('SELECT * FROM categories ORDER BY sort_order, name')).rows))
app.get('/api/v1/products', admin, async () =>
  success((await query('SELECT * FROM products ORDER BY name LIMIT 30')).rows))

app.post('/api/v1/admin/sections/:tabId/publish', {
  ...admin,
  schema: {
    params: {
      type: 'object', required: ['tabId'], properties: { tabId: { type: 'string', format: 'uuid' } },
    },
    body: {
      type: 'object', required: ['audience'], properties: { audience: { type: 'string', enum: ['B2C', 'B2B'] } },
    },
  },
}, async (request, reply) => {
  const result = await publishLayout(request.params.tabId, request.body.audience, request.user.id)
  return reply.code(result.status).send(result.body)
})

function imageType(data) {
  if (data.subarray(0, 8).equals(Buffer.from('89504e470d0a1a0a', 'hex'))) return 'image/png'
  if (data.subarray(0, 3).equals(Buffer.from('ffd8ff', 'hex'))) return 'image/jpeg'
  if (data.toString('ascii', 0, 4) === 'RIFF' && data.toString('ascii', 8, 12) === 'WEBP') return 'image/webp'
  return null
}

app.post('/api/v1/uploads/image', admin, async (request, reply) => {
  const file = await request.file()
  if (!file || file.fieldname !== 'image') return reply.code(400).send(error('Send one image file', 'IMAGE_REQUIRED'))
  const content = await file.toBuffer()
  const type = imageType(content)
  if (!type) return reply.code(415).send(error('Upload a PNG, JPEG or WebP image', 'IMAGE_TYPE'))
  const id = createHash('sha256').update(content).digest('hex')
  await query('INSERT INTO theme_bundle_media(id, content_type, content) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING', [id, type, content])
  const url = `/api/v1/theme/media/${id}`
  return reply.code(201).send(success({ url, secure_url: url, public_id: id }))
})

app.get('/api/v1/theme/media/:id', async (request, reply) => {
  if (!/^[a-f0-9]{64}$/.test(request.params.id)) return reply.code(404).send()
  const { rows: [file] } = await query('SELECT content_type, content FROM theme_bundle_media WHERE id = $1', [request.params.id])
  if (!file) return reply.code(404).send()
  return reply.type(file.content_type)
    .header('Access-Control-Allow-Origin', '*')
    .header('Cache-Control', 'public, max-age=31536000, immutable')
    .header('X-Content-Type-Options', 'nosniff')
    .send(file.content)
})

app.addHook('onClose', () => pool.end())
const port = Number(process.env.API_PORT ?? 4500)
await app.listen({ host: '127.0.0.1', port })
console.log(`Theme API listening on http://127.0.0.1:${port}`)
for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, () => void app.close())
