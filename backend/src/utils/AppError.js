'use strict';

/**
 * Error de negocio controlado.
 * Siempre viaja al cliente con un `code` estable (para i18n en la app)
 * y un `message` legible en español.
 */
class AppError extends Error {
  constructor(code, message, statusCode = 400, details = null) {
    super(message);
    this.name = 'AppError';
    this.code = code;
    this.statusCode = statusCode;
    this.details = details;
    this.isOperational = true;
    Error.captureStackTrace(this, this.constructor);
  }

  static badRequest(code, message, details) { return new AppError(code, message, 400, details); }
  static unauthorized(code, message, details) { return new AppError(code, message, 401, details); }
  static forbidden(code, message, details) { return new AppError(code, message, 403, details); }
  static notFound(code, message, details) { return new AppError(code, message, 404, details); }
  static conflict(code, message, details) { return new AppError(code, message, 409, details); }
  static tooMany(code, message, details) { return new AppError(code, message, 429, details); }
}

module.exports = AppError;
