'use strict';
const createApp = require('./app');
const env = require('./config/env');
const logger = require('./utils/logger');
const { migrate } = require('./config/database');

const app = createApp();

// En local sí se migra al arrancar: así `npm start` deja todo listo.
migrate().catch((err) => {
  logger.error('No se pudo preparar la base de datos', { error: err.message });
  process.exit(1);
});

const server = app.listen(env.port, '0.0.0.0', () => {
  logger.info('🚀 Remesas Auth API en marcha', {
    port: env.port, env: env.nodeEnv, prefix: env.apiPrefix,
  });
});

/** Apagado ordenado: deja terminar las peticiones en vuelo. */
for (const signal of ['SIGTERM', 'SIGINT']) {
  process.on(signal, () => {
    logger.info(`Señal ${signal} recibida, cerrando servidor...`);
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 10_000).unref();
  });
}

process.on('unhandledRejection', (reason) => logger.error('Promesa sin manejar', { reason: String(reason) }));

module.exports = server;
