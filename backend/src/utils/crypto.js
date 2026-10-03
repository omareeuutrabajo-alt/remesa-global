'use strict';
const crypto = require('node:crypto');

/** Token opaco de alta entropía (refresh / biometría / reset). */
const randomToken = (bytes = 48) => crypto.randomBytes(bytes).toString('hex');

/** SHA-256 en hex: así guardamos tokens largos sin coste de bcrypt. */
const sha256 = (value) => crypto.createHash('sha256').update(String(value)).digest('hex');

/** Comparación en tiempo constante para evitar timing attacks. */
function safeEqual(a = '', b = '') {
  const bufA = Buffer.from(String(a));
  const bufB = Buffer.from(String(b));
  if (bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
}

/** Código numérico criptográficamente seguro (sin sesgo de módulo). */
function numericCode(digits = 6) {
  const max = 10 ** digits;
  let value;
  do { value = crypto.randomBytes(4).readUInt32BE(0); } while (value >= Math.floor(4294967296 / max) * max);
  return String(value % max).padStart(digits, '0');
}

const uuid = () => crypto.randomUUID();

module.exports = { randomToken, sha256, safeEqual, numericCode, uuid };
