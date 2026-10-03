'use strict';
const { db, NOW_SQL } = require('../config/database');
const env = require('../config/env');
const AppError = require('../utils/AppError');
const { uuid, randomToken, sha256 } = require('../utils/crypto');
const jwtUtil = require('../utils/jwt');
const audit = require('./auditService');

const daysFromNow = (d) => new Date(Date.now() + d * 86_400_000).toISOString();

/** Emite el par access + refresh. El refresh se guarda **hasheado**. */
async function issuePair(user, { deviceId = null, req = null } = {}) {
  const refresh = randomToken(48);
  await db.prepare(
    `INSERT INTO refresh_tokens (id, user_id, token_hash, device_id, user_agent, ip, expires_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
  ).run(
    uuid(), user.id, sha256(refresh), deviceId,
    req?.get?.('user-agent') ?? null, req?.ip ?? null,
    daysFromNow(env.jwt.refreshTtlDays),
  );

  return {
    accessToken: jwtUtil.signAccessToken(user),
    refreshToken: refresh,
    tokenType: 'Bearer',
    expiresIn: jwtUtil.accessTtlSeconds(),
  };
}

/**
 * Rotación con detección de reuso:
 * si alguien presenta un refresh ya revocado, asumimos robo de token
 * y revocamos TODAS las sesiones del usuario.
 */
async function rotate(refreshToken, req = null) {
  const hash = sha256(refreshToken);
  const row = await db.prepare('SELECT * FROM refresh_tokens WHERE token_hash = ?').get(hash);
  if (!row) throw AppError.unauthorized('REFRESH_INVALID', 'Sesión inválida. Inicia sesión nuevamente.');

  if (row.revoked_at) {
    await revokeAllForUser(row.user_id);
    audit.log('auth.refresh_reuse_detected', { userId: row.user_id, req });
    throw AppError.unauthorized('REFRESH_REUSED', 'Se detectó un uso sospechoso. Vuelve a iniciar sesión.');
  }
  if (new Date(row.expires_at) < new Date()) {
    throw AppError.unauthorized('REFRESH_EXPIRED', 'La sesión expiró. Inicia sesión nuevamente.');
  }

  const user = await db.prepare('SELECT * FROM users WHERE id = ?').get(row.user_id);
  if (!user || user.status === 'suspended') {
    throw AppError.forbidden('ACCOUNT_SUSPENDED', 'La cuenta no está disponible.');
  }

  const pair = await issuePair(user, { deviceId: row.device_id, req });
  await db.prepare(
    `UPDATE refresh_tokens SET revoked_at = ${NOW_SQL}, replaced_by = ? WHERE id = ?`,
  ).run(sha256(pair.refreshToken), row.id);

  return { pair, user };
}

async function revoke(refreshToken) {
  await db.prepare(
    `UPDATE refresh_tokens SET revoked_at = ${NOW_SQL}
      WHERE token_hash = ? AND revoked_at IS NULL`,
  ).run(sha256(refreshToken));
}

async function revokeAllForUser(userId) {
  await db.prepare(
    `UPDATE refresh_tokens SET revoked_at = ${NOW_SQL}
      WHERE user_id = ? AND revoked_at IS NULL`,
  ).run(userId);
}

const activeSessions = (userId) =>
  db.prepare(
    `SELECT id, device_id, user_agent, ip, created_at, expires_at
       FROM refresh_tokens
      WHERE user_id = ? AND revoked_at IS NULL AND expires_at > ${NOW_SQL}
      ORDER BY created_at DESC`,
  ).all(userId);

module.exports = { issuePair, rotate, revoke, revokeAllForUser, activeSessions };
