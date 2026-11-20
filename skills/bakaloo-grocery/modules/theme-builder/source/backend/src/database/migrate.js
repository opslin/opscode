import { readdir, readFile } from 'node:fs/promises'
import { getClient, pool } from '../config/database.js'

const folder = new URL('./migrations/', import.meta.url)
const client = await getClient()
try {
  await client.query('SELECT pg_advisory_lock(824073, 6)')
  await client.query(`CREATE TABLE IF NOT EXISTS theme_bundle_migrations (
    name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now()
  )`)
  const { rows } = await client.query('SELECT name FROM theme_bundle_migrations')
  const alreadyApplied = new Set(rows.map(row => row.name))
  for (const file of (await readdir(folder)).filter(name => name.endsWith('.sql')).sort()) {
    if (alreadyApplied.has(file)) continue
    const sql = await readFile(new URL(file, folder), 'utf8')
    await client.query('BEGIN')
    try {
      await client.query(sql)
      await client.query('INSERT INTO theme_bundle_migrations(name) VALUES ($1)', [file])
      await client.query('COMMIT')
      console.log(`Applied ${file}`)
    } catch (error) {
      await client.query('ROLLBACK')
      throw new Error(`Migration ${file} failed`, { cause: error })
    }
  }
} finally {
  client.release()
  await pool.end()
}
