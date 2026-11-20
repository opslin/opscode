import { createHash } from 'node:crypto'
import { error, success } from '../../utils/apiResponse.js'
import { readPublishedLayout } from './publication.js'

export default async function publicThemeRoutes(fastify) {
  fastify.get('/tabs/:tabKey/sections', {
    schema: {
      params: {
        type: 'object', required: ['tabKey'],
        properties: { tabKey: { type: 'string', pattern: '^[a-z0-9_\\-]{1,50}$' } },
      },
      querystring: {
        type: 'object',
        properties: { store_key: { type: 'string', enum: ['zepto', 'off_zone', 'super_mall', 'cafe'] } },
      },
    },
  }, async (request, reply) => {
    const data = await readPublishedLayout(request.params.tabKey, request.query.store_key ?? 'zepto')
    reply.header('Access-Control-Allow-Origin', '*').header('Cache-Control', 'no-cache')
    if (!data) return reply.code(404).send(error('Tab not found', 'NOT_FOUND'))
    const etag = '"' + createHash('sha256').update(JSON.stringify(data)).digest('hex') + '"'
    reply.header('ETag', etag)
    if (request.headers['if-none-match'] === etag) return reply.code(304).send()
    return success(data, 'Section manifest')
  })
}
