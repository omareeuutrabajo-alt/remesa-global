'use strict';
const { z } = require('zod');

const email = z.string().trim().toLowerCase().email('Correo electrónico inválido');
const password = z.string().min(8, 'Mínimo 8 caracteres').max(128, 'Máximo 128 caracteres');
const phone = z.string().trim().regex(/^\+[1-9]\d{7,14}$/, 'Usa formato internacional, ej. +584121234567');
const pin = z.string().regex(/^\d{6}$/, 'El PIN debe tener exactamente 6 dígitos');
const otpCode = z.string().trim().regex(/^\d{6}$/, 'El código debe tener 6 dígitos');
const nombre = z.string().trim().min(2, 'Mínimo 2 caracteres').max(60, 'Máximo 60 caracteres')
  .regex(/^[\p{L}\s'’-]+$/u, 'Solo se permiten letras');

// Metadatos del dispositivo: opcionales pero recomendados (2FA + biometría).
const deviceMeta = {
  deviceId: z.string().trim().min(8).max(128).optional(),
  deviceName: z.string().trim().max(80).optional(),
  platform: z.enum(['android', 'ios', 'web']).optional(),
};

const schemas = {
  register: z.object({
    firstName: nombre,
    lastName: nombre,
    email,
    phone,
    countryCode: z.string().trim().length(2, 'Código ISO de 2 letras').toUpperCase(),
    password,
    acceptedTerms: z.literal(true, { errorMap: () => ({ message: 'Debes aceptar los términos y condiciones' }) }),
  }),

  login: z.object({ email, password: z.string().min(1, 'Ingresa tu contraseña'), ...deviceMeta }),

  verifyOtp: z.object({
    challengeId: z.string().uuid('Identificador de verificación inválido'),
    code: otpCode,
    trustDevice: z.boolean().optional().default(true),
    ...deviceMeta,
  }),

  resendOtp: z.object({ challengeId: z.string().uuid('Identificador de verificación inválido') }),

  forgotPassword: z.object({ email }),

  resetPassword: z.object({ resetToken: z.string().min(10), newPassword: password }),

  changePassword: z.object({ currentPassword: z.string().min(1), newPassword: password }),

  setPin: z.object({ pin, confirmPin: pin }).refine((d) => d.pin === d.confirmPin, {
    message: 'Los PIN no coinciden', path: ['confirmPin'],
  }),

  verifyPin: z.object({ pin }),

  biometricEnroll: z.object({
    deviceId: z.string().trim().min(8).max(128),
    deviceName: z.string().trim().max(80).optional(),
    platform: z.enum(['android', 'ios', 'web']).optional(),
  }),

  biometricLogin: z.object({
    deviceId: z.string().trim().min(8).max(128),
    biometricToken: z.string().trim().min(32),
  }),

  refresh: z.object({ refreshToken: z.string().trim().min(32, 'Token de sesión inválido') }),

  logout: z.object({ refreshToken: z.string().trim().min(32).optional(), allDevices: z.boolean().optional() }),

  kycSubmit: z.object({
    documentType: z.enum(['passport', 'national_id', 'drivers_license'], {
      errorMap: () => ({ message: 'Tipo de documento inválido' }),
    }),
    documentNumber: z.string().trim().min(5, 'Número de documento muy corto').max(32),
    birthDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Formato de fecha: AAAA-MM-DD').optional(),
    address: z.string().trim().max(160).optional(),
  }),
};

module.exports = schemas;
