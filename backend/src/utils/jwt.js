'use strict';
const jwt = require('jsonwebtoken');
const env = require('../config/env');
const AppError = require('./AppError');

const ISSUER = 'remesas-api';
const AUDIENCE = 'remesas-app';

/** Access token de vida corta: lo único que viaja en cada request. */
function signAccessToken(user, extra = {}) {
  return jwt.sign(
    {
      sub: user.id,
      email: user.email,
      kycStatus: user.kyc_status,
      kycLevel: user.kyc_level,
      type: 'access',
      ...extra,
    },
    env.jwt.accessSecret,
    { expiresIn: env.jwt.accessTtl, issuer: ISSUER, audience: AUDIENCE },
  );
}

/** Token de un solo uso para restablecer contraseña tras validar el OTP. */
function signResetToken(userId) {
  return jwt.sign({ sub: userId, type: 'password_reset' }, env.jwt.refreshSecret, {
    expiresIn: '10m', issuer: ISSUER, audience: AUDIENCE,
  });
}

function verify(token, secret, expectedType) {
  try {
    const payload = jwt.verify(token, secret, { issuer: ISSUER, audience: AUDIENCE });
    if (expectedType && payload.type !== expectedType) {
      throw AppError.unauthorized('TOKEN_TYPE_INVALID', 'El tipo de token no es válido.');
    }
    return payload;
  } catch (err) {
    if (err instanceof AppError) throw err;
    if (err.name === 'TokenExpiredError') {
      throw AppError.unauthorized('TOKEN_EXPIRED', 'La sesión expiró. Inicia sesión nuevamente.');
    }
    throw AppError.unauthorized('TOKEN_INVALID', 'Token inválido.');
  }
}

module.exports = {
  signAccessToken,
  signResetToken,
  verifyAccessToken: (t) => verify(t, env.jwt.accessSecret, 'access'),
  verifyResetToken: (t) => verify(t, env.jwt.refreshSecret, 'password_reset'),
  accessTtlSeconds: () => {
    const ttl = env.jwt.accessTtl;
    const m = /^(\d+)([smhd])$/.exec(ttl);
    if (!m) return Number(ttl) || 900;
    const mult = { s: 1, m: 60, h: 3600, d: 86400 }[m[2]];
    return Number(m[1]) * mult;
  },
};
