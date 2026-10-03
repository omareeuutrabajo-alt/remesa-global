'use strict';
/**
 * Almacenamiento de los documentos de KYC.
 *
 *   • local    → carpeta `uploads/` (desarrollo; no vale en serverless)
 *   • supabase → bucket PRIVADO de Supabase Storage (producción)
 *
 * El driver se elige solo: si hay credenciales de Supabase, se usa Supabase.
 * Nunca se devuelven URLs públicas: para ver un documento hay que pedir una
 * URL firmada de vida corta (back-office / revisión manual).
 */
const fs = require('node:fs');
const path = require('node:path');
const env = require('../config/env');
const { uuid } = require('../utils/crypto');
const logger = require('../utils/logger');

const SUPABASE_URL = (process.env.SUPABASE_URL || '').replace(/\/$/, '');
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const BUCKET = process.env.SUPABASE_KYC_BUCKET || 'kyc';

const driver = process.env.STORAGE_DRIVER || (SUPABASE_URL && SERVICE_KEY ? 'supabase' : 'local');

const extensiones = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/heic': '.heic',
};

/** Ruta relativa estable: un directorio por usuario (facilita el borrado). */
function rutaPara(userId, campo, fichero) {
  const ext = extensiones[fichero.mimetype]
    || path.extname(fichero.originalname || '').toLowerCase().slice(0, 6)
    || '.jpg';
  return `${userId}/${campo}-${Date.now()}-${uuid().slice(0, 8)}${ext}`;
}

/* ───────────────────────── Driver local ───────────────────────── */

const local = {
  async guardar(ruta, fichero) {
    const destino = path.join(env.kyc.uploadDir, ruta);
    fs.mkdirSync(path.dirname(destino), { recursive: true });
    fs.writeFileSync(destino, fichero.buffer);
    return ruta;
  },
  async urlFirmada(ruta) {
    return `file://${path.join(env.kyc.uploadDir, ruta)}`;
  },
  async purgar(userId) {
    fs.rmSync(path.join(env.kyc.uploadDir, userId), { recursive: true, force: true });
  },
};

/* ──────────────────────── Driver Supabase ──────────────────────── */

const cabeceras = (extra = {}) => ({
  Authorization: `Bearer ${SERVICE_KEY}`,
  apikey: SERVICE_KEY,
  ...extra,
});

let bucketListo = false;

/** Crea el bucket privado la primera vez (idempotente). */
async function asegurarBucket() {
  if (bucketListo) return;
  const res = await fetch(`${SUPABASE_URL}/storage/v1/bucket`, {
    method: 'POST',
    headers: cabeceras({ 'Content-Type': 'application/json' }),
    body: JSON.stringify({
      id: BUCKET,
      name: BUCKET,
      public: false,
      file_size_limit: env.kyc.maxUploadBytes,
      allowed_mime_types: Object.keys(extensiones),
    }),
  });
  // 409 = ya existía, que es el caso normal a partir del segundo arranque.
  if (!res.ok && res.status !== 409) {
    const detalle = await res.text();
    logger.warn('No se pudo crear el bucket de KYC', { status: res.status, detalle: detalle.slice(0, 200) });
  }
  bucketListo = true;
}

const supabase = {
  async guardar(ruta, fichero) {
    await asegurarBucket();
    const res = await fetch(`${SUPABASE_URL}/storage/v1/object/${BUCKET}/${ruta}`, {
      method: 'POST',
      headers: cabeceras({ 'Content-Type': fichero.mimetype, 'x-upsert': 'true' }),
      body: fichero.buffer,
    });
    if (!res.ok) {
      throw new Error(`Supabase Storage respondió ${res.status}: ${(await res.text()).slice(0, 200)}`);
    }
    return ruta;
  },

  async urlFirmada(ruta, segundos = 300) {
    const res = await fetch(`${SUPABASE_URL}/storage/v1/object/sign/${BUCKET}/${ruta}`, {
      method: 'POST',
      headers: cabeceras({ 'Content-Type': 'application/json' }),
      body: JSON.stringify({ expiresIn: segundos }),
    });
    if (!res.ok) return null;
    const { signedURL } = await res.json();
    return `${SUPABASE_URL}/storage/v1${signedURL}`;
  },

  async purgar(userId) {
    const lista = await fetch(`${SUPABASE_URL}/storage/v1/object/list/${BUCKET}`, {
      method: 'POST',
      headers: cabeceras({ 'Content-Type': 'application/json' }),
      body: JSON.stringify({ prefix: userId, limit: 100 }),
    });
    if (!lista.ok) return;
    const objetos = await lista.json();
    if (!objetos.length) return;
    await fetch(`${SUPABASE_URL}/storage/v1/object/${BUCKET}`, {
      method: 'DELETE',
      headers: cabeceras({ 'Content-Type': 'application/json' }),
      body: JSON.stringify({ prefixes: objetos.map((o) => `${userId}/${o.name}`) }),
    });
  },
};

const actual = driver === 'supabase' ? supabase : local;

/** Guarda un fichero recibido en memoria y devuelve su ruta relativa. */
async function guardar({ userId, campo, fichero }) {
  if (!fichero) return null;
  return actual.guardar(rutaPara(userId, campo, fichero), fichero);
}

module.exports = {
  driver,
  bucket: BUCKET,
  guardar,
  urlFirmada: (ruta, segundos) => (ruta ? actual.urlFirmada(ruta, segundos) : null),
  purgar: (userId) => actual.purgar(userId),
};
