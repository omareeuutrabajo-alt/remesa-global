'use strict';
const { db } = require('../config/database');
const { uuid } = require('../utils/crypto');
const logger = require('../utils/logger');
const clientIp = require('../utils/clientIp');

const stmt = () => db.prepare(
  `INSERT INTO audit_logs (id, user_id, event, ip, user_agent, metadata)
   VALUES (@id, @user_id, @event, @ip, @user_agent, @metadata)`,
);

/**
 * Registra un evento de seguridad. Nunca debe romper el flujo principal:
 * si falla la auditoría, se loguea y se continúa.
 */
function log(event, { userId = null, req = null, metadata = null } = {}) {
  // Deliberadamente sin `await`: la auditoría nunca debe frenar ni romper
  // la petición del usuario. Si falla, se registra y se sigue.
  try {
    stmt().run({
      id: uuid(),
      user_id: userId,
      event,
      ip: req ? clientIp(req) : null,
      user_agent: req?.get?.('user-agent') ?? null,
      metadata: metadata ? JSON.stringify(metadata) : null,
    }).catch((err) => logger.warn('No se pudo registrar auditoría', { event, error: err.message }));
  } catch (err) {
    logger.warn('No se pudo registrar auditoría', { event, error: err.message });
  }
}

const listByUser = (userId, limit = 20) =>
  db.prepare('SELECT event, ip, created_at FROM audit_logs WHERE user_id = ? ORDER BY created_at DESC LIMIT ?')
    .all(userId, limit);

module.exports = { log, listByUser };
