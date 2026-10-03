'use strict';
const logger = require('../utils/logger');
const env = require('../config/env');

/**
 * Pasarela de notificaciones (mock).
 * En producción se sustituye el cuerpo de estas funciones por Twilio / SendGrid
 * sin tocar el resto del código: la interfaz se mantiene.
 */
async function sendSms(phone, message) {
  logger.info('📱 SMS enviado', { to: phone, message: env.isProd ? '***' : message });
  return { provider: 'mock-sms', deliveredAt: new Date().toISOString() };
}

async function sendEmail(email, subject, message) {
  logger.info('✉️  Email enviado', { to: email, subject, message: env.isProd ? '***' : message });
  return { provider: 'mock-email', deliveredAt: new Date().toISOString() };
}

const PLANTILLAS = {
  register: (code) => `Tu código de verificación de Remesas es ${code}. Vence en 5 minutos. Nunca lo compartas.`,
  login: (code) => `Código para iniciar sesión: ${code}. Si no fuiste tú, cambia tu contraseña.`,
  password_reset: (code) => `Código para restablecer tu contraseña: ${code}. Vence en 5 minutos.`,
  transaction: (code) => `Autoriza tu envío con el código ${code}.`,
};

async function sendOtp({ purpose, code, channel, email, phone }) {
  const text = (PLANTILLAS[purpose] || PLANTILLAS.login)(code);
  return channel === 'email'
    ? sendEmail(email, 'Tu código de verificación', text)
    : sendSms(phone, text);
}

module.exports = { sendSms, sendEmail, sendOtp };
