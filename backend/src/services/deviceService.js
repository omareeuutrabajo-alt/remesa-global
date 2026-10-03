'use strict';
const { db, NOW_SQL } = require('../config/database');
const { uuid, sha256, randomToken, safeEqual } = require('../utils/crypto');
const AppError = require('../utils/AppError');

const find = (userId, deviceId) =>
  db.prepare('SELECT * FROM devices WHERE user_id = ? AND device_id = ?').get(userId, deviceId);

/** Registra el dispositivo o actualiza su última conexión. */
async function upsert({ userId, deviceId, deviceName, platform }) {
  if (!deviceId) return null;
  const existing = await find(userId, deviceId);
  if (existing) {
    await db.prepare(`UPDATE devices SET last_seen_at = ${NOW_SQL}, device_name = COALESCE(?::text, device_name),
                platform = COALESCE(?::text, platform) WHERE id = ?`)
      .run(deviceName ?? null, platform ?? null, existing.id);
    return find(userId, deviceId);
  }
  await db.prepare(
    `INSERT INTO devices (id, user_id, device_id, device_name, platform, last_seen_at)
     VALUES (?, ?, ?, ?, ?, ${NOW_SQL})`,
  ).run(uuid(), userId, deviceId, deviceName ?? null, platform ?? null);
  return find(userId, deviceId);
}

/** Un dispositivo "de confianza" se salta el OTP en los siguientes logins. */
async function trust(userId, deviceId) {
  if (!deviceId) return;
  await upsert({ userId, deviceId });
  await db.prepare('UPDATE devices SET trusted = 1 WHERE user_id = ? AND device_id = ?').run(userId, deviceId);
}

const isTrusted = async (userId, deviceId) =>
  Boolean(deviceId && (await find(userId, deviceId))?.trusted);

/** Vincula un token biométrico opaco a un dispositivo concreto. */
async function enrollBiometric({ userId, deviceId, deviceName, platform }) {
  await upsert({ userId, deviceId, deviceName, platform });
  const token = randomToken(32);
  await db.prepare(
    `UPDATE devices SET biometric_token_hash = ?, biometric_enabled = 1, trusted = 1
      WHERE user_id = ? AND device_id = ?`,
  ).run(sha256(token), userId, deviceId);
  return token;
}

async function disableBiometric(userId, deviceId) {
  await db.prepare(
    `UPDATE devices SET biometric_token_hash = NULL, biometric_enabled = 0
      WHERE user_id = ? AND device_id = ?`,
  ).run(userId, deviceId);
}

/** Resuelve el dueño de un token biométrico. Error genérico si no cuadra. */
async function resolveBiometric({ deviceId, biometricToken }) {
  const device = await db.prepare(
    'SELECT * FROM devices WHERE device_id = ? AND biometric_enabled = 1',
  ).get(deviceId);
  if (!device || !device.biometric_token_hash || !safeEqual(sha256(biometricToken), device.biometric_token_hash)) {
    throw AppError.unauthorized('BIOMETRIC_INVALID', 'No se pudo validar la biometría. Usa tu contraseña.');
  }
  await db.prepare(`UPDATE devices SET last_seen_at = ${NOW_SQL} WHERE id = ?`).run(device.id);
  return device;
}

const listByUser = (userId) =>
  db.prepare(
    `SELECT device_id, device_name, platform, biometric_enabled, trusted, last_seen_at
       FROM devices WHERE user_id = ? ORDER BY last_seen_at DESC`,
  ).all(userId);

module.exports = { find, upsert, trust, isTrusted, enrollBiometric, disableBiometric, resolveBiometric, listByUser };
