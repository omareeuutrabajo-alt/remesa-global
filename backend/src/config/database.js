'use strict';
/**
 * Acceso a PostgreSQL (Supabase en producción, Postgres local en desarrollo).
 *
 * Expone la misma forma que usaba `better-sqlite3`
 *   db.prepare(sql).get(...)  /  .all(...)  /  .run(...)
 * pero devolviendo promesas, para que los servicios se lean igual que antes.
 *
 * Traduce los marcadores al dialecto de Postgres:
 *   posicionales   SELECT … WHERE id = ?        →  $1
 *   nombrados      INSERT … VALUES (@id, @email) →  $1, $2
 */
const fs = require('node:fs');
const path = require('node:path');
const { Pool } = require('pg');
const logger = require('../utils/logger');

/** Fecha actual en el mismo formato ISO-8601 que guarda la API. */
const NOW_SQL = `to_char((now() AT TIME ZONE 'utc'), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')`;

const CONEXION =
  process.env.DATABASE_URL ||
  process.env.SUPABASE_DB_URL ||
  'postgresql://postgres:postgres@127.0.0.1:5432/remesas';

// Supabase (y cualquier Postgres gestionado) exige TLS. El pooler usa un
// certificado propio, así que no se valida la cadena pero sí se cifra.
const necesitaTls = /supabase|sslmode=require|ssl=true/i.test(CONEXION);

// En serverless cada instancia vive poco: una conexión por instancia y
// a través del pooler de Supabase (puerto 6543, modo transacción).
const esServerless = Boolean(process.env.NETLIFY || process.env.AWS_LAMBDA_FUNCTION_NAME);

const pool = new Pool({
  connectionString: CONEXION,
  max: Number(process.env.PG_POOL_MAX || (esServerless ? 1 : 10)),
  idleTimeoutMillis: esServerless ? 2_000 : 30_000,
  connectionTimeoutMillis: 15_000,
  ssl: necesitaTls ? { rejectUnauthorized: false } : undefined,
  application_name: 'remesas-auth-api',
});

// Un error de red en una conexión inactiva no debe tumbar el proceso.
pool.on('error', (err) => logger.warn('Conexión Postgres inactiva cerrada', { error: err.message }));

/* ───────────────── Traducción de marcadores ───────────────── */

const cachePosicional = new Map();
const cacheNombrado = new Map();

function compilarPosicional(sql) {
  let compilado = cachePosicional.get(sql);
  if (!compilado) {
    let n = 0;
    compilado = sql.replace(/\?/g, () => `$${++n}`);
    cachePosicional.set(sql, compilado);
  }
  return compilado;
}

function compilarNombrado(sql) {
  let compilado = cacheNombrado.get(sql);
  if (!compilado) {
    const orden = [];
    const texto = sql.replace(/@([a-zA-Z_][a-zA-Z0-9_]*)/g, (_m, nombre) => {
      let i = orden.indexOf(nombre);
      if (i === -1) i = orden.push(nombre) - 1;
      return `$${i + 1}`;
    });
    compilado = { texto, orden };
    cacheNombrado.set(sql, compilado);
  }
  return compilado;
}

const esObjetoPlano = (v) =>
  typeof v === 'object' && v !== null && !Array.isArray(v) && !Buffer.isBuffer(v) && !(v instanceof Date);

const normalizar = (v) => (v === undefined ? null : v);

async function ejecutar(sql, args) {
  let texto;
  let valores;

  if (args.length === 1 && esObjetoPlano(args[0]) && sql.includes('@')) {
    const { texto: t, orden } = compilarNombrado(sql);
    texto = t;
    valores = orden.map((nombre) => normalizar(args[0][nombre]));
  } else {
    texto = compilarPosicional(sql);
    valores = args.map(normalizar);
  }

  try {
    return await pool.query(texto, valores);
  } catch (err) {
    logger.error('Consulta SQL fallida', { error: err.message, sql: texto.slice(0, 160) });
    throw err;
  }
}

/** Mismo contrato que better-sqlite3, pero asíncrono. */
function prepare(sql) {
  return {
    get: async (...args) => (await ejecutar(sql, args)).rows[0],
    all: async (...args) => (await ejecutar(sql, args)).rows,
    run: async (...args) => ({ changes: (await ejecutar(sql, args)).rowCount }),
  };
}

const db = { prepare, query: (sql, valores = []) => pool.query(sql, valores), pool };

/* ─────────────────────── Migraciones ─────────────────────── */

const DIR_MIGRACIONES = path.resolve(__dirname, '../../../supabase/migrations');

/** Aplica, en orden, todos los .sql de supabase/migrations (idempotentes). */
async function migrate() {
  const ficheros = fs.existsSync(DIR_MIGRACIONES)
    ? fs.readdirSync(DIR_MIGRACIONES).filter((f) => f.endsWith('.sql')).sort()
    : [];

  if (!ficheros.length) throw new Error(`No hay migraciones en ${DIR_MIGRACIONES}`);

  for (const fichero of ficheros) {
    const sql = fs.readFileSync(path.join(DIR_MIGRACIONES, fichero), 'utf8');
    await pool.query(sql);
  }
  logger.info('Base de datos lista', { migraciones: ficheros.length, host: hostVisible() });
}

/** Comprueba que la base responde (se usa en /health). */
async function ping() {
  const { rows } = await pool.query('SELECT 1 AS ok');
  return rows[0]?.ok === 1;
}

const hostVisible = () => {
  try {
    const u = new URL(CONEXION);
    return `${u.hostname}:${u.port || 5432}/${u.pathname.slice(1)}`;
  } catch {
    return 'desconocido';
  }
};

const close = () => pool.end();

module.exports = { db, migrate, ping, close, NOW_SQL, DATABASE_URL: CONEXION, hostVisible };
