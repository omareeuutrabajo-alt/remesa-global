'use strict';
const rateLimit = require('express-rate-limit');
const env = require('../config/env');
const clientIp = require('../utils/clientIp');

const build = (windowMinutes, max, code, message) =>
  rateLimit({
    windowMs: windowMinutes * 60_000,
    max: env.isProd ? max : max * 10, // en desarrollo no estorbamos las pruebas
    standardHeaders: true,
    legacyHeaders: false,
    // Clave explícita: en serverless `req.ip` no existe (no hay socket).
    keyGenerator: (req) => clientIp(req),
    // El almacén en memoria vive por instancia; en Netlify cada contenedor
    // lleva su propia cuenta. Es suficiente como freno de abuso básico;
    // para producción real: store compartido (Redis/Upstash).
    validate: { ip: false, xForwardedForHeader: false },
    handler: (_req, res) => res.status(429).json({ success: false, error: { code, message } }),
  });

module.exports = {
  global: build(15, 300, 'RATE_LIMITED', 'Demasiadas solicitudes. Intenta más tarde.'),
  register: build(60, 5, 'RATE_LIMITED_REGISTER', 'Demasiados registros desde esta red. Intenta más tarde.'),
  login: build(15, 10, 'RATE_LIMITED_LOGIN', 'Demasiados intentos de inicio de sesión. Espera unos minutos.'),
  otp: build(15, 15, 'RATE_LIMITED_OTP', 'Demasiadas verificaciones. Espera unos minutos.'),
  sensitive: build(60, 10, 'RATE_LIMITED', 'Demasiadas solicitudes para esta operación.'),
};
