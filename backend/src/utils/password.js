'use strict';
const bcrypt = require('bcryptjs');
const env = require('../config/env');

const hash = (plain) => bcrypt.hash(plain, env.security.bcryptRounds);
const compare = (plain, hashed) => (hashed ? bcrypt.compare(plain, hashed) : Promise.resolve(false));

/**
 * Puntúa la fortaleza de una contraseña (0-4). Misma lógica que el medidor
 * visual del cliente Flutter, para que servidor y app coincidan.
 */
function strength(pwd = '') {
  let score = 0;
  if (pwd.length >= 8) score++;
  if (pwd.length >= 12) score++;
  if (/[a-z]/.test(pwd) && /[A-Z]/.test(pwd)) score++;
  if (/\d/.test(pwd)) score++;
  if (/[^A-Za-z0-9]/.test(pwd)) score++;
  return Math.min(score, 4);
}

module.exports = { hash, compare, strength };
