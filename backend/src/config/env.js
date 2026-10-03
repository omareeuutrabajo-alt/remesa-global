'use strict';
require('dotenv').config();

const path = require('node:path');

/** Lee una variable de entorno obligatoria (falla rápido si falta). */
function required(name, fallback) {
  const value = process.env[name] ?? fallback;
  if (value === undefined || value === '') {
    throw new Error(`[config] Falta la variable de entorno obligatoria: ${name}`);
  }
  return value;
}

const num = (name, fallback) => Number(process.env[name] ?? fallback);
const bool = (name, fallback = false) =>
  String(process.env[name] ?? fallback).toLowerCase() === 'true';

const env = {
  nodeEnv: process.env.NODE_ENV || 'development',
  isProd: (process.env.NODE_ENV || 'development') === 'production',
  port: num('PORT', 4000),
  apiPrefix: process.env.API_PREFIX || '/api/v1',

  jwt: {
    accessSecret: required('JWT_ACCESS_SECRET', 'dev_access_secret'),
    refreshSecret: required('JWT_REFRESH_SECRET', 'dev_refresh_secret'),
    accessTtl: process.env.ACCESS_TOKEN_TTL || '15m',
    refreshTtlDays: num('REFRESH_TOKEN_TTL_DAYS', 30),
  },

  security: {
    bcryptRounds: num('BCRYPT_ROUNDS', 12),
    maxLoginAttempts: num('MAX_LOGIN_ATTEMPTS', 5),
    lockMinutes: num('LOCK_MINUTES', 15),
    otpTtlMinutes: num('OTP_TTL_MINUTES', 5),
    otpMaxAttempts: num('OTP_MAX_ATTEMPTS', 5),
    otpResendCooldownSeconds: num('OTP_RESEND_COOLDOWN_SECONDS', 60),
    maxPinAttempts: num('MAX_PIN_ATTEMPTS', 5),
  },

  kyc: {
    uploadDir: path.resolve(__dirname, '../../', process.env.UPLOAD_DIR || 'uploads'),
    maxUploadBytes: num('MAX_UPLOAD_MB', 8) * 1024 * 1024,
    autoReviewMs: num('KYC_AUTO_REVIEW_MS', 10000),
  },

  dev: {
    exposeOtp: bool('EXPOSE_OTP_IN_RESPONSE', true),
  },

  // Vitrina pública: el despliegue es una demostración, no una remesadora
  // real. Sin proveedor de SMS ni de verificación documental, el modo demo
  // mantiene visible el código OTP y la aprobación automática del KYC para
  // que cualquiera pueda recorrer el flujo completo.
  demo: {
    enabled: bool('DEMO_MODE', (process.env.NODE_ENV || 'development') !== 'production'),
  },
};

// Guardarraíl: nunca exponer OTP ni secretos de desarrollo en producción real.
if (env.isProd && !env.demo.enabled) {
  env.dev.exposeOtp = false;
}
if (env.isProd && (env.jwt.accessSecret.startsWith('dev_') || env.jwt.refreshSecret.startsWith('dev_'))) {
  // Esto no se relaja ni en modo demo: los secretos siempre son propios.
  throw new Error('[config] Secretos JWT de desarrollo detectados en producción. Abortando.');
}

module.exports = env;
