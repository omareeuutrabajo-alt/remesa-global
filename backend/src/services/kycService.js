'use strict';
const { db, NOW_SQL } = require('../config/database');
const env = require('../config/env');
const AppError = require('../utils/AppError');
const { uuid } = require('../utils/crypto');
const users = require('./userService');
const audit = require('./auditService');
const storage = require('./storageService');
const logger = require('../utils/logger');

const latest = (userId) =>
  db.prepare('SELECT * FROM kyc_submissions WHERE user_id = ? ORDER BY created_at DESC LIMIT 1').get(userId);

// En Lambda/Netlify no hay temporizadores fiables después de responder.
const ES_SERVERLESS = Boolean(process.env.NETLIFY || process.env.AWS_LAMBDA_FUNCTION_NAME);
const autoRevisionActiva = () => env.kyc.autoReviewMs > 0 && (!env.isProd || env.demo.enabled);

/**
 * Resuelve el expediente si ya cumplió el tiempo de "revisión" simulada.
 * Se invoca al consultar el estado: así la demo funciona igual en un
 * servidor normal que en una función sin estado.
 */
async function resolverPendientePorTiempo(userId) {
  if (!autoRevisionActiva()) return;
  const s = await latest(userId);
  if (!s || s.status !== 'in_review') return;
  const transcurrido = Date.now() - new Date(s.created_at).getTime();
  if (transcurrido < env.kyc.autoReviewMs) return;
  await review({ submissionId: s.id, approved: true, reason: null, automated: true })
    .catch((err) => logger.warn('Auto-revisión perezosa falló', { error: err.message }));
}

function toPublic(s) {
  if (!s) return null;
  return {
    id: s.id,
    documentType: s.document_type,
    // Solo los 4 últimos caracteres alfanuméricos (PCI/PII).
    documentNumber: `****${String(s.document_number).replace(/[^a-zA-Z0-9]/g, '').slice(-4)}`,
    status: s.status,
    rejectionReason: s.rejection_reason,
    submittedAt: s.created_at,
    reviewedAt: s.reviewed_at,
  };
}

/**
 * Crea un expediente KYC. Los ficheros llegan en memoria (multer) y se
 * suben al almacenamiento configurado: disco en local, bucket privado de
 * Supabase Storage en producción.
 * Nivel 1 = identidad verificada (habilita envíos hasta cierto monto).
 */
async function submit({ userId, documentType, documentNumber, birthDate, address, files }, req) {
  const current = await latest(userId);
  if (current && current.status === 'in_review') {
    throw AppError.conflict('KYC_IN_REVIEW', 'Ya tienes una verificación en curso.');
  }
  if (current && current.status === 'approved') {
    throw AppError.conflict('KYC_ALREADY_APPROVED', 'Tu identidad ya fue verificada.');
  }
  if (!files?.documentFront?.[0] || !files?.selfie?.[0]) {
    throw AppError.badRequest('KYC_FILES_REQUIRED', 'Debes adjuntar el documento y la selfie.');
  }
  if (documentType !== 'passport' && !files?.documentBack?.[0]) {
    throw AppError.badRequest('KYC_BACK_REQUIRED', 'Debes adjuntar el reverso del documento.');
  }

  let rutas;
  try {
    rutas = await Promise.all([
      storage.guardar({ userId, campo: 'documentFront', fichero: files.documentFront[0] }),
      storage.guardar({ userId, campo: 'documentBack', fichero: files.documentBack?.[0] }),
      storage.guardar({ userId, campo: 'selfie', fichero: files.selfie[0] }),
    ]);
  } catch (err) {
    logger.error('Fallo al guardar documentos de KYC', { error: err.message, driver: storage.driver });
    throw AppError.internal('KYC_STORAGE_FAILED', 'No pudimos guardar tus documentos. Inténtalo de nuevo.');
  }

  const [frente, reverso, selfie] = rutas;
  const id = uuid();
  await db.prepare(
    `INSERT INTO kyc_submissions
       (id, user_id, document_type, document_number, birth_date, address,
        document_front_path, document_back_path, selfie_path, status)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'in_review')`,
  ).run(id, userId, documentType, documentNumber, birthDate ?? null, address ?? null, frente, reverso, selfie);

  await users.update(userId, { kyc_status: 'in_review' });
  audit.log('kyc.submitted', { userId, req, metadata: { documentType, driver: storage.driver } });

  // Simulación del proveedor de verificación (Jumio/Onfido).
  // En un servidor de larga vida basta un temporizador; en serverless el
  // proceso se congela tras responder, así que la revisión se resuelve
  // además de forma perezosa cuando el cliente consulta el estado.
  if (autoRevisionActiva() && !ES_SERVERLESS) {
    setTimeout(() => {
      review({ submissionId: id, approved: true, reason: null, automated: true })
        .catch((err) => logger.warn('Auto-revisión KYC falló', { error: err.message }));
    }, env.kyc.autoReviewMs).unref?.();
  }

  return { submission: toPublic(await latest(userId)), estimatedMinutes: env.isProd ? 10 : 1 };
}

/** Resolución del expediente (webhook del proveedor o back-office). */
async function review({ submissionId, approved, reason = null, automated = false }) {
  const submission = await db.prepare('SELECT * FROM kyc_submissions WHERE id = ?').get(submissionId);
  if (!submission) throw AppError.notFound('KYC_NOT_FOUND', 'Expediente no encontrado.');
  if (submission.status !== 'in_review') return toPublic(submission);

  await db.prepare(
    `UPDATE kyc_submissions SET status = ?, rejection_reason = ?, reviewed_at = ${NOW_SQL} WHERE id = ?`,
  ).run(approved ? 'approved' : 'rejected', approved ? null : reason, submissionId);

  await users.update(submission.user_id, {
    kyc_status: approved ? 'approved' : 'rejected',
    kyc_level: approved ? 1 : 0,
  });
  audit.log(approved ? 'kyc.approved' : 'kyc.rejected', {
    userId: submission.user_id, metadata: { automated, reason },
  });
  return toPublic(await db.prepare('SELECT * FROM kyc_submissions WHERE id = ?').get(submissionId));
}

/** Límites de envío por nivel KYC (reglas de negocio de la remesadora). */
function limitsFor(level) {
  const tabla = {
    0: { perTransaction: 0, daily: 0, monthly: 0, label: 'Sin verificar' },
    1: { perTransaction: 1000, daily: 2000, monthly: 10000, label: 'Verificado' },
    2: { perTransaction: 5000, daily: 10000, monthly: 50000, label: 'Verificado plus' },
  };
  return { level, currency: 'USD', ...(tabla[level] ?? tabla[0]) };
}

async function status(userId) {
  await resolverPendientePorTiempo(userId);
  const user = await users.findById(userId);
  return {
    kycStatus: user.kyc_status,
    kycLevel: user.kyc_level,
    limits: limitsFor(user.kyc_level),
    submission: toPublic(await latest(userId)),
    nextStep: users.nextStep(user),
  };
}

/**
 * URLs temporales de los documentos (revisión manual / back-office).
 * Nunca se exponen al usuario final ni se guardan en ningún sitio.
 */
async function signedFiles(submissionId, segundos = 300) {
  const s = await db.prepare('SELECT * FROM kyc_submissions WHERE id = ?').get(submissionId);
  if (!s) throw AppError.notFound('KYC_NOT_FOUND', 'Expediente no encontrado.');
  const [documentFront, documentBack, selfie] = await Promise.all([
    storage.urlFirmada(s.document_front_path, segundos),
    storage.urlFirmada(s.document_back_path, segundos),
    storage.urlFirmada(s.selfie_path, segundos),
  ]);
  return { documentFront, documentBack, selfie, expiresInSeconds: segundos };
}

/** Elimina los archivos de un expediente (derecho al olvido / GDPR). */
async function purgeFiles(userId) {
  await storage.purgar(userId);
  audit.log('kyc.files_purged', { userId });
}

module.exports = { submit, review, status, limitsFor, latest, toPublic, signedFiles, purgeFiles };
