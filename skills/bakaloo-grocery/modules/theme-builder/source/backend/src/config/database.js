import pg from 'pg'

if (!process.env.DATABASE_URL) {
  throw new Error('Set DATABASE_URL to the standalone theme-builder PostgreSQL database')
}

export const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL })
export const query = (text, params) => pool.query(text, params)
export const getClient = () => pool.connect()
