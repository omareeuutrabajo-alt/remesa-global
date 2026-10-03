'use strict';
const { db, NOW_SQL } = require('../config/database');
const env = require('../config/env');
const AppError = require('../utils/AppError');
const { uuid, numericCode, sha256, safeEqual } = require('../utils/crypto');
const notifications = require('./notificationService');
const audit = require('./auditService');

const minutesFromNow = (m) => new Date(Date.now() + m * 60_000).toISOString();

/**
 * Genera y envía un OTP.
 * - Invalida los códigos previos del mismo propósito (un solo código vivo).
 * - Aplica cooldown de reenvío para evitar bombardeo de SMS (coste real).
 */
async function issue({ user, purpose, channel = 'sms', req = null }) {
  const last = await db.prepare(
    `SELECT created_at FROM otp_codes
      WHERE user_id = ? AND purpose = ? ORDER BY created_at DESC LIMIT 1`,
  ).get(user.id, purpose);

  if (last) {
    const elapsed = (Date.now() - new Date(last.created_at).getTime()) / 1000;
    const cooldown = env.security.otpResendCooldownSeconds;
    if (elapsed >= 0 && elapsed < cooldown) {
      throw AppError.tooMany(
        'OTP_COOLDOWN',
        `Espera ${Math.ceil(cooldown - elapsed)} segundos antes de solicitar otro código.`,
        { retryAfterSeconds: Math.ceil(cooldown - elapsed) },
      );
    }
  }

  await db.prepare(
    `UPDATE otp_codes SET consumed_at = ${NOW_SQL}
      WHERE user_id = ? AND purpose = ? AND consumed_at IS NULL`,
  ).run(user.id, purpose);

  const code = numericCode(6);
  const id = uuid();
  await db.prepare(
    `INSERT INTO otp_codes (id, user_id, purpose, channel, code_hash, expires_at)
     VALUES (?, ?, ?, ?, ?, ?)`,
  ).run(id, user.id, purpose, channel, sha256(code), minutesFromNow(env.security.otpTtlMinutes));

  await notifications.sendOtp({ purpose, code, channel, email: user.email, phone: user.phone });
  audit.log('otp.issued', { userId: user.id, req, metadata: { purpose, channel } });

  return {
    challengeId: id,
    expiresInSeconds: env.security.otpTtlMinutes * 60,
    // Solo en desarrollo: permite probar el flujo completo sin SMS real.
    devCode: env.dev.exposeOtp ? code : undefined,
  };
}

/** Valida un OTP y lo marca como consumido. Devuelve el registro para el flujo. */
async function verify({ challengeId, code, purpose, req = null }) {
  const otp = await db.prepare('SELECT * FROM otp_codes WHERE id = ?').get(challengeId);
  if (!otp || (purpose && otp.purpose !== purpose)) {
    throw AppError.badRequest('OTP_NOT_FOUND', 'El código de verificación no existe o ya fue usado.');
  }
  if (otp.consumed_at) {
    throw AppError.badRequest('OTP_ALREADY_USED', 'Este código ya fue utilizado. Solicita uno nuevo.');
  }
  if (new Date(otp.expires_at) < new Date()) {
    throw AppError.badRequest('OTP_EXPIRED', 'El código expiró. Solicita uno nuevo.');
  }
  if (otp.attempts >= env.security.otpMaxAttempts) {
    await db.prepare(`UPDATE otp_codes SET consumed_at = ${NOW_SQL} WHERE id = ?`).run(otp.id);
    audit.log('otp.max_attempts', { userId: otp.user_id, req, metadata: { purpose: otp.purpose } });
    throw AppError.tooMany('OTP_MAX_ATTEMPTS', 'Demasiados intentos fallidos. Solicita un código nuevo.');
  }

  if (!safeEqual(sha256(String(code)), otp.code_hash)) {
    await db.prepare('UPDATE otp_codes SET attempts = attempts + 1 WHERE id = ?').run(otp.id);
    const left = env.security.otpMaxAttempts - (otp.attempts + 1);
    audit.log('otp.failed', { userId: otp.user_id, req, metadata: { purpose: otp.purpose, left } });
    throw AppError.badRequest('OTP_INVALID', 'Código incorrecto. Verifica e inténtalo de nuevo.', {
      attemptsLeft: Math.max(left, 0),
    });
  }

  await db.prepare(`UPDATE otp_codes SET consumed_at = ${NOW_SQL} WHERE id = ?`).run(otp.id);
  audit.log('otp.verified', { userId: otp.user_id, req, metadata: { purpose: otp.purpose } });
  return otp;
}

module.exports = { issue, verify };
