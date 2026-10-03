'use strict';

/** jose.perez@mail.com -> j******z@mail.com */
function maskEmail(email = '') {
  const [user = '', domain = ''] = email.split('@');
  if (user.length <= 2) return `${user[0] || '*'}***@${domain}`;
  const estrellas = '*'.repeat(Math.min(Math.max(user.length - 2, 3), 6));
  return `${user[0]}${estrellas}${user.at(-1)}@${domain}`;
}

/** +584121234567 -> +58 *** *** 4567 */
function maskPhone(phone = '') {
  const digits = String(phone).replace(/\D/g, '');
  if (digits.length < 4) return '****';
  const last = digits.slice(-4);
  const prefix = String(phone).startsWith('+') ? `+${digits.slice(0, 2)} ` : '';
  return `${prefix}*** *** ${last}`;
}

module.exports = { maskEmail, maskPhone };
