import { getClient, query } from '../../config/database.js'
import { error, success } from '../../utils/apiResponse.js'

const supported = new Set(['text_header', 'spacer', 'custom_banner', 'fee_strip'])
const mediaPath = /^\/api\/v1\/theme\/media\/([0-9a-f]{64})$/

export function mediaId(path) {
  return typeof path === 'string' ? path.match(mediaPath)?.[1] : undefined
}

export async function publishLayout(tabId, audience, adminId) {
  const client = await getClient()
  let transactionOpen = false
  try {
    await client.query('BEGIN')
    transactionOpen = true
    const { rowCount } = await client.query(
      "SELECT id FROM theme_tabs WHERE id = $1 AND audience = $2 AND status = 'active' FOR UPDATE",
      [tabId, audience]
    )
    if (!rowCount) return { status: 404, body: error('Active tab not found', 'NOT_FOUND') }

    const { rows: sections } = await client.query(
      'SELECT * FROM section_manifests WHERE tab_id = $1 AND audience = $2 ORDER BY sort_order, id',
      [tabId, audience]
    )
    if (sections.length > 50 || sections.some(section => !supported.has(section.section_type))) {
      return { status: 422, body: error('This bundle supports up to 50 text, banner, fee strip, and spacer sections', 'UNSUPPORTED_LAYOUT') }
    }
    for (const section of sections.filter(item => item.visible)) {
      if (section.section_type !== 'custom_banner' && section.section_type !== 'fee_strip') continue
      if (section.section_type === 'fee_strip' && (!section.config.image_url || section.config.visible === false)) continue
      const id = mediaId(section.config.image_url)
      const available = id && (await client.query('SELECT 1 FROM theme_bundle_media WHERE id = $1', [id])).rowCount
      if (!available) {
        return { status: 422, body: error('Upload bundled banner images through the editor before publishing', 'MISSING_BANNER') }
      }
    }

    const { rows: [version] } = await client.query(`
      INSERT INTO section_manifest_versions(tab_id, audience, version, snapshot, created_by)
      SELECT $1::uuid, $2::varchar, COALESCE(MAX(version), 0) + 1, $3::jsonb, $4::uuid FROM section_manifest_versions
      WHERE tab_id = $1 AND audience = $2
      RETURNING id, version, created_at
    `, [tabId, audience, JSON.stringify(sections), adminId])
    await client.query(`
      INSERT INTO theme_bundle_publications(tab_id, version_id) VALUES ($1, $2)
      ON CONFLICT (tab_id) DO UPDATE SET version_id = EXCLUDED.version_id, published_at = now()
    `, [tabId, version.id])
    await client.query('COMMIT')
    transactionOpen = false
    return { status: 200, body: success(version, 'Homepage published') }
  } finally {
    try {
      if (transactionOpen) await client.query('ROLLBACK')
    } finally {
      client.release()
    }
  }
}

export async function readPublishedLayout(tabKey, storeKey) {
  const { rows: [layout] } = await query(`
    SELECT tab.key AS tab_key, tab.store_key, version.version, version.snapshot
    FROM theme_tabs tab
    LEFT JOIN theme_bundle_publications active ON active.tab_id = tab.id
    LEFT JOIN section_manifest_versions version ON version.id = active.version_id
    WHERE tab.key = $1 AND tab.store_key = $2 AND tab.status = 'active' AND tab.audience = 'B2C'
  `, [tabKey, storeKey])
  if (!layout) return null
  return {
    tab_key: layout.tab_key,
    store_key: layout.store_key,
    revision: layout.version ?? 0,
    sections: (layout.snapshot ?? []).filter(section => section.visible),
  }
}
