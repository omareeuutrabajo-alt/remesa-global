'use strict';
const { db, NOW_SQL } = require('../config/database');

const findById = (id) => db.prepare('SELECT * FROM users WHERE id = ?').get(id);
const findByEmail = (email) => db.prepare('SELECT * FROM users WHERE email = ?').get(String(email).toLowerCase());
const findByPhone = (phone) => db.prepare('SELECT * FROM users WHERE phone = ?').get(phone);

async function create(user) {
  await db.prepare(
    `INSERT INTO users (id, first_name, last_name, email, phone, country_code, password_hash)
     VALUES (@id, @first_name, @last_name, @email, @phone, @country_code, @password_hash)`,
  ).run(user);
  return findById(user.id);
}

async function update(id, fields) {
  const keys = Object.keys(fields);
  if (!keys.length) return findById(id);
  const sets = keys.map((k) => `${k} = @${k}`).join(', ');
  await db.prepare(`UPDATE users SET ${sets}, updated_at = ${NOW_SQL} WHERE id = @id`).run({ ...fields, id });
  return findById(id);
}

/** Proyección pública: nunca expone hashes ni contadores internos. */
function toPublic(u) {
  if (!u) return null;
  return {
    id: u.id,
    firstName: u.first_name,
    lastName: u.last_name,
    fullName: `${u.first_name} ${u.last_name}`,
    email: u.email,
    phone: u.phone,
    countryCode: u.country_code,
    status: u.status,
    emailVerified: !!u.email_verified,
    phoneVerified: !!u.phone_verified,
    hasPin: !!u.pin_hash,
    kycLevel: u.kyc_level,
    kycStatus: u.kyc_status,
    lastLoginAt: u.last_login_at,
    createdAt: u.created_at,
  };
}

/**
 * Siguiente paso del onboarding. La app Flutter usa este valor
 * para decidir a qué pantalla navegar (una única fuente de verdad).
 */
function nextStep(u) {
  if (!u.email_verified && !u.phone_verified) return 'verify_otp';
  if (!u.pin_hash) return 'pin_setup';
  if (u.kyc_status === 'not_started' || u.kyc_status === 'rejected') return 'kyc';
  if (u.kyc_status === 'in_review') return 'kyc_pending';
  return 'home';
}

module.exports = { findById, findByEmail, findByPhone, create, update, toPublic, nextStep };
