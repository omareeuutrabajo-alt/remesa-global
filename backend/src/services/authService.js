'use strict';
const { db } = require('../config/database');
const env = require('../config/env');
const AppError = require('../utils/AppError');
const { uuid } = require('../utils/crypto');
const passwordUtil = require('../utils/password');
const jwtUtil = require('../utils/jwt');
const { maskEmail, maskPhone } = require('../utils/mask');

const users = require('./userService');
const tokens = require('./tokenService');
const otp = require('./otpService');
const devices = require('./deviceService');
const audit = require('./auditService');

const minutesFromNow = (m) => new Date(Date.now() + m * 60_000).toISOString();

/* ════════════════════════════ Registro ════════════════════════════ */

async function register({ firstName, lastName, email, phone, countryCode, password }, req) {
  const normalizedEmail = email.toLowerCase().trim();

  if (await users.findByEmail(normalizedEmail)) {
    throw AppError.conflict('EMAIL_TAKEN', 'Ya existe una cuenta con este correo.');
  }
  if (await users.findByPhone(phone)) {
    throw AppError.conflict('PHONE_TAKEN', 'Ya existe una cuenta con este teléfono.');
  }
  if (passwordUtil.strength(password) < 3) {
    throw AppError.badRequest(
      'PASSWORD_WEAK',
      'La contraseña es muy débil: usa mayúsculas, minúsculas, números y al menos 8 caracteres.',
    );
  }

  const user = await users.create({
    id: uuid(),
    first_name: firstName.trim(),
    last_name: lastName.trim(),
    email: normalizedEmail,
    phone: phone.trim(),
    country_code: countryCode,
    password_hash: await passwordUtil.hash(password),
  });

  audit.log('auth.registered', { userId: user.id, req, metadata: { countryCode } });
  const challenge = await otp.issue({ user, purpose: 'register', channel: 'sms', req });

  return {
    userId: user.id,
    requiresOtp: true,
    purpose: 'register',
    maskedPhone: maskPhone(user.phone),
    maskedEmail: maskEmail(user.email),
    ...challenge,
  };
}

/* ═════════════════════════════ Login ═════════════════════════════ */

function assertNotLocked(user) {
  if (user.locked_until && new Date(user.locked_until) > new Date()) {
    const mins = Math.ceil((new Date(user.locked_until) - Date.now()) / 60000);
    throw AppError.forbidden(
      'ACCOUNT_LOCKED',
      `Cuenta bloqueada temporalmente por seguridad. Inténtalo en ${mins} minuto(s).`,
      { lockedUntil: user.locked_until },
    );
  }
  if (user.status === 'suspended') {
    throw AppError.forbidden('ACCOUNT_SUSPENDED', 'Tu cuenta está suspendida. Contacta a soporte.');
  }
}

async function login({ email, password, deviceId, deviceName, platform }, req) {
  const user = await users.findByEmail(email);

  // Mensaje genérico: no revelamos si el correo existe (anti-enumeración).
  const invalid = AppError.unauthorized('INVALID_CREDENTIALS', 'Correo o contraseña incorrectos.');
  if (!user) {
    await passwordUtil.compare(password, '$2a$12$invalidinvalidinvalidinvalidinvalidinvalidinvalidinv');
    throw invalid;
  }

  assertNotLocked(user);

  if (!(await passwordUtil.compare(password, user.password_hash))) {
    const attempts = user.failed_login_attempts + 1;
    const shouldLock = attempts >= env.security.maxLoginAttempts;
    await users.update(user.id, {
      failed_login_attempts: shouldLock ? 0 : attempts,
      locked_until: shouldLock ? minutesFromNow(env.security.lockMinutes) : null,
    });
    audit.log('auth.login_failed', { userId: user.id, req, metadata: { attempts } });
    if (shouldLock) {
      throw AppError.forbidden(
        'ACCOUNT_LOCKED',
        `Demasiados intentos fallidos. Cuenta bloqueada por ${env.security.lockMinutes} minutos.`,
      );
    }
    throw AppError.unauthorized('INVALID_CREDENTIALS', 'Correo o contraseña incorrectos.', {
      attemptsLeft: env.security.maxLoginAttempts - attempts,
    });
  }

  await users.update(user.id, { failed_login_attempts: 0, locked_until: null });
  await devices.upsert({ userId: user.id, deviceId, deviceName, platform });

  // Cuenta sin verificar → se reanuda el flujo de registro.
  if (!user.email_verified && !user.phone_verified) {
    const challenge = await otp.issue({ user, purpose: 'register', channel: 'sms', req });
    return {
      requiresOtp: true, purpose: 'register', userId: user.id,
      maskedPhone: maskPhone(user.phone), nextStep: 'verify_otp', ...challenge,
    };
  }

  // Dispositivo conocido → sin segundo factor. Dispositivo nuevo → OTP.
  if (!(await devices.isTrusted(user.id, deviceId))) {
    const challenge = await otp.issue({ user, purpose: 'login', channel: 'sms', req });
    audit.log('auth.login_otp_required', { userId: user.id, req, metadata: { deviceId } });
    return {
      requiresOtp: true, purpose: 'login', userId: user.id,
      maskedPhone: maskPhone(user.phone), nextStep: 'verify_otp', ...challenge,
    };
  }

  return completeLogin(user, { deviceId, req, event: 'auth.login_trusted_device' });
}

/** Paso final común: marca el login y emite tokens. */
async function completeLogin(user, { deviceId, req, event = 'auth.login' }) {
  const fresh = await users.update(user.id, { last_login_at: new Date().toISOString() });
  audit.log(event, { userId: fresh.id, req, metadata: { deviceId } });
  return {
    requiresOtp: false,
    user: users.toPublic(fresh),
    nextStep: users.nextStep(fresh),
    tokens: await tokens.issuePair(fresh, { deviceId, req }),
  };
}

/* ══════════════════════════ OTP ══════════════════════════ */

async function verifyOtp({ challengeId, code, deviceId, deviceName, platform, trustDevice = true }, req) {
  const record = await otp.verify({ challengeId, code, req });
  const user = await users.findById(record.user_id);
  if (!user) throw AppError.notFound('USER_NOT_FOUND', 'Usuario no encontrado.');

  await devices.upsert({ userId: user.id, deviceId, deviceName, platform });

  if (record.purpose === 'register') {
    const activated = await users.update(user.id, {
      email_verified: 1, phone_verified: 1, status: 'active',
    });
    if (trustDevice) await devices.trust(user.id, deviceId);
    audit.log('auth.account_verified', { userId: user.id, req });
    return completeLogin(activated, { deviceId, req, event: 'auth.login_after_register' });
  }

  if (record.purpose === 'login') {
    if (trustDevice) await devices.trust(user.id, deviceId);
    return completeLogin(user, { deviceId, req, event: 'auth.login_otp_verified' });
  }

  if (record.purpose === 'password_reset') {
    return { purpose: 'password_reset', resetToken: jwtUtil.signResetToken(user.id), expiresIn: 600 };
  }

  throw AppError.badRequest('OTP_PURPOSE_UNSUPPORTED', 'Propósito de verificación no soportado.');
}

/** Reenvía el código a partir del challenge previo (no expone al usuario). */
async function resendOtp({ challengeId }, req) {
  const record = await db.prepare('SELECT * FROM otp_codes WHERE id = ?').get(challengeId);
  if (!record) throw AppError.notFound('OTP_NOT_FOUND', 'Solicitud de verificación no encontrada.');
  const user = await users.findById(record.user_id);
  if (!user) throw AppError.notFound('USER_NOT_FOUND', 'Usuario no encontrado.');

  const challenge = await otp.issue({ user, purpose: record.purpose, channel: record.channel, req });
  return { purpose: record.purpose, maskedPhone: maskPhone(user.phone), ...challenge };
}

/* ═══════════════════ Recuperación de contraseña ═══════════════════ */

async function forgotPassword({ email }, req) {
  const user = await users.findByEmail(email);
  // Respuesta idéntica exista o no la cuenta (anti-enumeración).
  const generic = { requiresOtp: true, purpose: 'password_reset', message: 'Si el correo existe, enviamos un código.' };
  if (!user) {
    audit.log('auth.forgot_password_unknown_email', { req, metadata: { email } });
    return generic;
  }
  const challenge = await otp.issue({ user, purpose: 'password_reset', channel: 'email', req });
  return { ...generic, maskedEmail: maskEmail(user.email), ...challenge };
}

async function resetPassword({ resetToken, newPassword }, req) {
  const payload = jwtUtil.verifyResetToken(resetToken);
  const user = await users.findById(payload.sub);
  if (!user) throw AppError.notFound('USER_NOT_FOUND', 'Usuario no encontrado.');
  if (passwordUtil.strength(newPassword) < 3) {
    throw AppError.badRequest('PASSWORD_WEAK', 'La contraseña es muy débil.');
  }
  if (await passwordUtil.compare(newPassword, user.password_hash)) {
    throw AppError.badRequest('PASSWORD_REUSED', 'La nueva contraseña no puede ser igual a la anterior.');
  }

  await users.update(user.id, {
    password_hash: await passwordUtil.hash(newPassword),
    failed_login_attempts: 0,
    locked_until: null,
  });
  // Cambio de credencial ⇒ se cierran todas las sesiones abiertas.
  await tokens.revokeAllForUser(user.id);
  audit.log('auth.password_reset', { userId: user.id, req });
  return { message: 'Contraseña actualizada. Inicia sesión con tu nueva contraseña.' };
}

async function changePassword({ userId, currentPassword, newPassword }, req) {
  const user = await users.findById(userId);
  if (!(await passwordUtil.compare(currentPassword, user.password_hash))) {
    throw AppError.unauthorized('INVALID_CREDENTIALS', 'La contraseña actual no es correcta.');
  }
  if (passwordUtil.strength(newPassword) < 3) {
    throw AppError.badRequest('PASSWORD_WEAK', 'La contraseña es muy débil.');
  }
  await users.update(userId, { password_hash: await passwordUtil.hash(newPassword) });
  await tokens.revokeAllForUser(userId);
  audit.log('auth.password_changed', { userId, req });
  return { message: 'Contraseña actualizada. Vuelve a iniciar sesión.' };
}

/* ═══════════════════════════ PIN ═══════════════════════════ */

const PINES_DEBILES = new Set(['000000', '111111', '123456', '654321', '121212', '112233', '123123']);

async function setPin({ userId, pin }, req) {
  if (!/^\d{6}$/.test(pin)) throw AppError.badRequest('PIN_FORMAT', 'El PIN debe tener 6 dígitos.');
  if (PINES_DEBILES.has(pin)) {
    throw AppError.badRequest('PIN_WEAK', 'Ese PIN es demasiado común. Elige otro.');
  }
  if (/^(\d)\1{5}$/.test(pin)) throw AppError.badRequest('PIN_WEAK', 'No uses un PIN con dígitos repetidos.');

  const user = await users.update(userId, { pin_hash: await passwordUtil.hash(pin), failed_pin_attempts: 0 });
  audit.log('auth.pin_set', { userId, req });
  return { message: 'PIN configurado correctamente.', nextStep: users.nextStep(user) };
}

async function verifyPin({ userId, pin }, req) {
  const user = await users.findById(userId);
  if (!user?.pin_hash) throw AppError.badRequest('PIN_NOT_SET', 'Aún no configuraste un PIN.');
  assertNotLocked(user);

  if (!(await passwordUtil.compare(pin, user.pin_hash))) {
    const attempts = user.failed_pin_attempts + 1;
    const shouldLock = attempts >= env.security.maxPinAttempts;
    await users.update(userId, {
      failed_pin_attempts: shouldLock ? 0 : attempts,
      locked_until: shouldLock ? minutesFromNow(env.security.lockMinutes) : null,
    });
    audit.log('auth.pin_failed', { userId, req, metadata: { attempts } });
    if (shouldLock) {
      await tokens.revokeAllForUser(userId);
      throw AppError.forbidden('ACCOUNT_LOCKED', 'Demasiados intentos. Vuelve a iniciar sesión con tu contraseña.');
    }
    throw AppError.unauthorized('PIN_INVALID', 'PIN incorrecto.', {
      attemptsLeft: env.security.maxPinAttempts - attempts,
    });
  }

  await users.update(userId, { failed_pin_attempts: 0 });
  audit.log('auth.pin_verified', { userId, req });
  return { verified: true };
}

/* ════════════════════════ Biometría ════════════════════════ */

async function enrollBiometric({ userId, deviceId, deviceName, platform }, req) {
  if (!deviceId) throw AppError.badRequest('DEVICE_REQUIRED', 'Falta el identificador del dispositivo.');
  const token = await devices.enrollBiometric({ userId, deviceId, deviceName, platform });
  audit.log('auth.biometric_enrolled', { userId, req, metadata: { deviceId } });
  return { biometricToken: token, message: 'Biometría activada en este dispositivo.' };
}

async function biometricLogin({ deviceId, biometricToken }, req) {
  const device = await devices.resolveBiometric({ deviceId, biometricToken });
  const user = await users.findById(device.user_id);
  if (!user) throw AppError.unauthorized('BIOMETRIC_INVALID', 'No se pudo validar la biometría.');
  assertNotLocked(user);
  return completeLogin(user, { deviceId, req, event: 'auth.login_biometric' });
}

/* ════════════════════════ Sesiones ════════════════════════ */

async function refresh({ refreshToken }, req) {
  const { pair, user } = await tokens.rotate(refreshToken, req);
  audit.log('auth.token_refreshed', { userId: user.id, req });
  return { tokens: pair, user: users.toPublic(user), nextStep: users.nextStep(user) };
}

async function logout({ refreshToken, userId, allDevices = false }, req) {
  if (allDevices && userId) await tokens.revokeAllForUser(userId);
  else if (refreshToken) await tokens.revoke(refreshToken);
  audit.log('auth.logout', { userId, req, metadata: { allDevices } });
  return { message: 'Sesión cerrada correctamente.' };
}

module.exports = {
  register, login, completeLogin, verifyOtp, resendOtp,
  forgotPassword, resetPassword, changePassword,
  setPin, verifyPin, enrollBiometric, biometricLogin,
  refresh, logout,
};
