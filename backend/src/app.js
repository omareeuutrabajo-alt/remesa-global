'use strict';
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const path = require('node:path');
const fs = require('node:fs');

const env = require('./config/env');
const logger = require('./utils/logger');
const { migrate, ping, hostVisible } = require('./config/database');
const limiter = require('./middleware/rateLimiter');
const { notFound, errorHandler } = require('./middleware/errorHandler');

/**
 * Construye la app de Express. No toca la base de datos: en serverless el
 * arranque debe ser inmediato y las migraciones se aplican en el despliegue
 * (`npm run migrate`), no en cada invocación.
 */
function createApp() {
  const app = express();

  // Detrás de un proxy (Nginx/Cloud Run) para obtener la IP real en rate limit.
  app.set('trust proxy', 1);
  app.disable('x-powered-by');

  // Cabeceras de seguridad. La CSP está afinada para poder servir el cliente
  // Flutter Web (CanvasKit necesita WebAssembly y workers desde blob:).
  app.use(helmet({
    contentSecurityPolicy: {
      useDefaults: false,
      directives: {
        defaultSrc: ["'self'"],
        baseUri: ["'self'"],
        formAction: ["'self'"],
        objectSrc: ["'none'"],
        scriptSrc: ["'self'", "'wasm-unsafe-eval'", 'blob:'],
        workerSrc: ["'self'", 'blob:'],
        childSrc: ["'self'", 'blob:'],
        styleSrc: ["'self'", "'unsafe-inline'"],
        imgSrc: ["'self'", 'data:', 'blob:'],
        // fonts.gstatic.com: Flutter Web descarga de ahí la tipografía de
        // emoji (banderas de los países). En móvil nativo no hace falta.
        fontSrc: ["'self'", 'data:', 'https://fonts.gstatic.com'],
        // blob: es imprescindible en web: image_picker entrega las fotos como
        // blob URL y el cliente las lee con fetch antes de subirlas al KYC.
        connectSrc: ["'self'", 'data:', 'blob:', 'https://fonts.gstatic.com'],
        // En producción solo se permite embeber desde el propio dominio.
        frameAncestors: env.isProd ? ["'self'"] : ['*'],
        ...(env.isProd ? { upgradeInsecureRequests: [] } : {}),
      },
    },
    // Fuera de producción se permite la vista previa embebida del entorno.
    frameguard: env.isProd ? { action: 'sameorigin' } : false,
    crossOriginResourcePolicy: { policy: 'cross-origin' },
    crossOriginEmbedderPolicy: false,
    crossOriginOpenerPolicy: env.isProd ? { policy: 'same-origin' } : false,
  }));
  app.use(cors({ origin: true, credentials: true }));
  app.use(express.json({ limit: '1mb' }));
  app.use(express.urlencoded({ extended: true }));
  if (!env.isProd) app.use(morgan('dev'));
  app.use(limiter.global);

  app.get('/health', async (_req, res) => {
    let db = 'ok';
    try { await ping(); } catch (err) { db = `error: ${err.message}`; }
    res.status(db === 'ok' ? 200 : 503).json({
      success: db === 'ok',
      data: {
        status: db === 'ok' ? 'ok' : 'degradado',
        database: { estado: db, host: hostVisible() },
        storage: require('./services/storageService').driver,
        uptime: Math.round(process.uptime()),
        timestamp: new Date().toISOString(),
      },
    });
  });

  // Consola de pruebas (sirve docs/console.html) y documentación de endpoints.
  app.use('/docs', express.static(path.resolve(__dirname, '../docs')));

  app.use(env.apiPrefix, require('./routes'));

  // Demostración: si existe el build web de Flutter, se sirve desde el mismo
  // origen que la API. Así el cliente usa rutas relativas y no hay CORS.
  const webBuild = path.resolve(__dirname, '../../mobile/build/web');
  if (fs.existsSync(path.join(webBuild, 'index.html'))) {
    app.use(express.static(webBuild));
    app.get(/^\/(?!api|health|docs).*/, (req, res, next) => {
      if (!req.accepts('html')) return next();
      res.sendFile(path.join(webBuild, 'index.html'));
    });
    logger.info('Build web de Flutter servido en /', { path: webBuild });
  }

  app.use(notFound);
  app.use(errorHandler);
  return app;
}

module.exports = createApp;
