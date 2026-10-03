'use strict';
/**
 * Punto de entrada serverless: envuelve la misma app de Express que se usa
 * en local. No hay código duplicado entre el servidor tradicional y Netlify.
 *
 * La app se construye una sola vez por contenedor (fuera del handler) para
 * aprovechar los arranques en caliente; el pool de Postgres se limita a una
 * conexión por instancia (ver config/database.js) porque cada invocación
 * concurrente levanta su propio contenedor.
 */
const serverless = require('serverless-http');
const createApp = require('../../backend/src/app');

const app = createApp();

const handler = serverless(app, {
  binary: ['image/*', 'application/octet-stream', 'multipart/form-data'],
  request(req, event) {
    // Conserva la IP real del cliente para el rate limiter y la auditoría.
    req.headers['x-forwarded-for'] =
      req.headers['x-forwarded-for'] || event.headers?.['client-ip'] || '';
  },
});

const PREFIJO_FUNCION = '/.netlify/functions/api';

/**
 * Normaliza la ruta: según cómo llegue la petición (redirección de
 * netlify.toml o llamada directa a la función) el path puede venir con o sin
 * el prefijo interno. La app sólo entiende /api/v1/... , /health y /docs.
 */
function normalizar(ruta = '/') {
  let r = ruta.startsWith(PREFIJO_FUNCION) ? ruta.slice(PREFIJO_FUNCION.length) : ruta;
  if (!r.startsWith('/')) r = `/${r}`;
  if (r === '/' || r === '') return '/health';
  if (r.startsWith('/api/')) return r;
  if (/^\/v\d+\//.test(r)) return `/api${r}`;   // /v1/auth/login → /api/v1/auth/login
  return r;                                     // /health, /docs, ...
}

exports.handler = async (event, context) => {
  // Permite responder sin esperar a que el pool de Postgres quede ocioso.
  context.callbackWaitsForEmptyEventLoop = false;
  return handler({ ...event, path: normalizar(event.path), rawPath: normalizar(event.rawPath || event.path) }, context);
};
