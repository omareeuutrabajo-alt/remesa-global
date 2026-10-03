'use strict';
/**
 * IP real del cliente.
 *
 * Detrás de un proxy normal Express la resuelve solo (`trust proxy`), pero en
 * una función serverless no hay socket: `req.ip` queda indefinido y el
 * limitador de peticiones metería a todo el mundo en el mismo cubo. Por eso
 * se cae hacia las cabeceras que inyecta la plataforma.
 */
function clientIp(req) {
  const h = req?.headers || {};
  const reenviada = h['x-nf-client-connection-ip'] || h['client-ip'] || h['x-real-ip'];
  if (reenviada) return String(reenviada).trim();

  const cadena = h['x-forwarded-for'];
  if (cadena) {
    // El primer elemento es el cliente original; el resto son proxies.
    const primera = String(cadena).split(',')[0].trim();
    if (primera) return primera;
  }
  return req?.ip || req?.socket?.remoteAddress || '0.0.0.0';
}

module.exports = clientIp;
