'use strict';
const multer = require('multer');
const AppError = require('../utils/AppError');
const env = require('../config/env');
const logger = require('../utils/logger');

function notFound(req, _res, next) {
  next(AppError.notFound('ROUTE_NOT_FOUND', `Ruta no encontrada: ${req.method} ${req.originalUrl}`));
}

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, _next) {
  let error = err;

  if (err instanceof multer.MulterError) {
    const map = {
      LIMIT_FILE_SIZE: ['FILE_TOO_LARGE', `El archivo supera el máximo de ${env.kyc.maxUploadBytes / 1048576} MB.`],
      LIMIT_UNEXPECTED_FILE: ['FILE_UNEXPECTED', 'Campo de archivo no esperado.'],
    };
    const [code, message] = map[err.code] || ['UPLOAD_ERROR', 'No se pudo procesar el archivo.'];
    error = AppError.badRequest(code, message);
  }

  if (err?.code === 'SQLITE_CONSTRAINT_UNIQUE') {
    error = AppError.conflict('DUPLICATE_RESOURCE', 'El registro ya existe.');
  }

  if (!(error instanceof AppError)) {
    logger.error('Error no controlado', { message: err.message, stack: err.stack, path: req.originalUrl });
    error = new AppError('INTERNAL_ERROR', 'Ocurrió un error inesperado. Intenta nuevamente.', 500);
  } else if (error.statusCode >= 500) {
    logger.error(error.message, { code: error.code, path: req.originalUrl });
  } else {
    logger.warn(error.message, { code: error.code, path: req.originalUrl });
  }

  res.status(error.statusCode).json({
    success: false,
    error: {
      code: error.code,
      message: error.message,
      ...(error.details ? { details: error.details } : {}),
      ...(env.isProd ? {} : { path: req.originalUrl }),
    },
  });
}

module.exports = { notFound, errorHandler };
