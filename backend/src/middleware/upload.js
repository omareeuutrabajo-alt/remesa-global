'use strict';
const multer = require('multer');
const env = require('../config/env');
const AppError = require('../utils/AppError');

const TIPOS_PERMITIDOS = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/heic']);

// En memoria: el destino real (disco o Supabase Storage) lo decide
// `storageService`, porque en serverless no hay disco persistente.
const storage = multer.memoryStorage();

const kycUpload = multer({
  storage,
  limits: { fileSize: env.kyc.maxUploadBytes, files: 3 },
  fileFilter(_req, file, cb) {
    if (!TIPOS_PERMITIDOS.has(file.mimetype)) {
      return cb(AppError.badRequest('FILE_TYPE_INVALID', 'Formato no permitido. Usa JPG, PNG o WEBP.'));
    }
    cb(null, true);
  },
}).fields([
  { name: 'documentFront', maxCount: 1 },
  { name: 'documentBack', maxCount: 1 },
  { name: 'selfie', maxCount: 1 },
]);

module.exports = { kycUpload };
