'use strict';
const env = require('../config/env');

const LEVELS = { debug: 10, info: 20, warn: 30, error: 40 };
const MIN = env.isProd ? LEVELS.info : LEVELS.debug;

/** Oculta datos sensibles antes de escribir en consola. */
function redact(meta) {
  if (!meta || typeof meta !== 'object') return meta;
  const clone = { ...meta };
  for (const key of ['password', 'pin', 'code', 'token', 'refreshToken', 'biometricToken']) {
    if (key in clone) clone[key] = '***';
  }
  return clone;
}

function write(level, msg, meta) {
  if (LEVELS[level] < MIN) return;
  const line = { ts: new Date().toISOString(), level, msg, ...(meta ? redact(meta) : {}) };
  const out = level === 'error' ? console.error : console.log;
  out(env.isProd ? JSON.stringify(line) : `${line.ts} [${level.toUpperCase()}] ${msg}` +
    (meta ? ` ${JSON.stringify(redact(meta))}` : ''));
}

module.exports = {
  debug: (m, meta) => write('debug', m, meta),
  info: (m, meta) => write('info', m, meta),
  warn: (m, meta) => write('warn', m, meta),
  error: (m, meta) => write('error', m, meta),
};
