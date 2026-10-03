'use strict';
const AppError = require('../utils/AppError');

/**
 * Valida `req[source]` contra un esquema Zod y reemplaza el valor
 * por la versión parseada (tipos ya coercionados y saneados).
 */
const validate = (schema, source = 'body') => (req, _res, next) => {
  const result = schema.safeParse(req[source]);
  if (!result.success) {
    const details = result.error.issues.map((i) => ({
      field: i.path.join('.') || '(raíz)',
      message: i.message,
    }));
    return next(AppError.badRequest('VALIDATION_ERROR', 'Revisa los datos enviados.', details));
  }
  req[source] = result.data;
  next();
};

module.exports = validate;
