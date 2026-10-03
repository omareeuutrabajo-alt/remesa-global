'use strict';
const AppError = require('../utils/AppError');
const jwtUtil = require('../utils/jwt');
const users = require('../services/userService');

/** Exige un access token válido y adjunta `req.user`. */
async function requireAuth(req, _res, next) {
  try {
    const header = req.get('authorization') || '';
    const [scheme, token] = header.split(' ');
    if (scheme !== 'Bearer' || !token) {
      throw AppError.unauthorized('TOKEN_MISSING', 'Falta el token de acceso.');
    }
    const payload = jwtUtil.verifyAccessToken(token);
    const user = await users.findById(payload.sub);
    if (!user) throw AppError.unauthorized('USER_NOT_FOUND', 'Usuario no encontrado.');
    if (user.status === 'suspended') {
      throw AppError.forbidden('ACCOUNT_SUSPENDED', 'Tu cuenta está suspendida.');
    }
    req.user = user;
    req.userId = user.id;
    next();
  } catch (err) { next(err); }
}

/** Protege endpoints que exigen KYC aprobado (p. ej. enviar dinero). */
function requireKyc(minLevel = 1) {
  return (req, _res, next) => {
    if (!req.user) return next(AppError.unauthorized('TOKEN_MISSING', 'Sesión requerida.'));
    if (req.user.kyc_status !== 'approved' || req.user.kyc_level < minLevel) {
      return next(AppError.forbidden('KYC_REQUIRED', 'Debes verificar tu identidad para continuar.', {
        kycStatus: req.user.kyc_status, kycLevel: req.user.kyc_level, requiredLevel: minLevel,
      }));
    }
    next();
  };
}

module.exports = { requireAuth, requireKyc };
