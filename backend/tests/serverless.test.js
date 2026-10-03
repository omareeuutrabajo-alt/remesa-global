#!/usr/bin/env node
'use strict';
/**
 * Pruebas de la función de Netlify: invoca el handler con eventos idénticos
 * a los que genera la plataforma, sin levantar ningún servidor HTTP.
 *
 * Cubre lo que en un servidor normal nunca falla pero en serverless sí:
 *   · la ruta llega con el prefijo interno /.netlify/functions/api
 *   · el cuerpo multipart viaja en base64
 *   · no hay socket, así que `req.ip` no existe (rate limit y auditoría)
 *   · los temporizadores no sobreviven a la respuesta (auto-revisión del KYC)
 *
 * Requiere Postgres en marcha (npm run db:local) y DATABASE_URL.
 *   node tests/serverless.test.js
 */
const assert = require('node:assert');

process.env.NETLIFY = 'true';
process.env.NODE_ENV = 'production';
process.env.DEMO_MODE = 'true';
process.env.KYC_AUTO_REVIEW_MS = '1200';
process.env.BCRYPT_ROUNDS = '10';
process.env.STORAGE_DRIVER = 'local';
process.env.JWT_ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || 'secreto_de_prueba_serverless_acceso_0001';
process.env.JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'secreto_de_prueba_serverless_refresco_0002';
process.env.DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres:postgres@127.0.0.1:5432/remesas';

const { handler } = require('../../netlify/functions/api');
const { close } = require('../src/config/database');

const ctx = { callbackWaitsForEmptyEventLoop: true };
const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  'base64',
);

const evento = (metodo, ruta, { body, token, headers } = {}) => ({
  httpMethod: metodo,
  path: ruta,
  rawUrl: `https://demo.netlify.app${ruta}`,
  headers: {
    host: 'demo.netlify.app',
    'x-nf-client-connection-ip': '198.51.100.7',
    ...(body ? { 'content-type': 'application/json' } : {}),
    ...(token ? { authorization: `Bearer ${token}` } : {}),
    ...headers,
  },
  body: body ? JSON.stringify(body) : null,
  isBase64Encoded: false,
});

async function invocar(ev) {
  const r = await handler(ev, ctx);
  let cuerpo;
  try { cuerpo = JSON.parse(r.body); } catch { cuerpo = r.body; }
  return { code: r.statusCode, ...cuerpo };
}

let fallos = 0;
let superadas = 0;
const seccion = (t) => console.log(`\n\x1b[36m${t}\x1b[0m`);
function prueba(nombre, fn) {
  try {
    fn(); superadas++; console.log(`  \x1b[32m✔\x1b[0m ${nombre}`);
  } catch (err) {
    fallos++; console.log(`  \x1b[31m✘\x1b[0m ${nombre}\n      ${err.message}`);
  }
}

(async () => {
  const marca = Date.now();
  const correo = `serverless.${marca}@remesas.app`;

  seccion('1. Enrutado dentro de la función');

  const salud = await invocar(evento('GET', '/health'));
  prueba('GET /health responde y ve la base de datos', () => {
    assert.equal(salud.code, 200);
    assert.equal(salud.data.database.estado, 'ok');
  });

  const saludInterna = await invocar(evento('GET', '/.netlify/functions/api/health'));
  prueba('La ruta interna /.netlify/functions/api/* se normaliza', () => {
    assert.equal(saludInterna.code, 200);
  });

  const conPrefijo = await invocar(evento('GET', '/.netlify/functions/api/v1/auth/me'));
  prueba('/.netlify/functions/api/v1/… llega a /api/v1/… (401 sin token, no 404)', () => {
    assert.equal(conPrefijo.code, 401);
    assert.equal(conPrefijo.error.code, 'TOKEN_MISSING');
  });

  const inexistente = await invocar(evento('GET', '/api/v1/no-existe'));
  prueba('Una ruta desconocida da 404 con el formato de error de la API', () => {
    assert.equal(inexistente.code, 404);
    assert.equal(inexistente.error.code, 'ROUTE_NOT_FOUND');
  });

  seccion('2. Modo demostración en producción');

  const alta = await invocar(evento('POST', '/api/v1/auth/register', {
    body: {
      firstName: 'Luis', lastName: 'Serverless', email: correo,
      phone: `+5841${String(marca).slice(-7)}`, countryCode: 'VE',
      password: 'Remesas2026$Seg', acceptedTerms: true,
    },
  }));
  prueba('Registro correcto con NODE_ENV=production', () => assert.equal(alta.code, 201));
  prueba('DEMO_MODE deja ver el código OTP (sin él la demo sería imposible)', () => {
    assert.match(String(alta.data.devCode), /^\d{6}$/);
  });

  const verificado = await invocar(evento('POST', '/api/v1/auth/otp/verify', {
    body: { challengeId: alta.data.challengeId, code: alta.data.devCode },
  }));
  const token = verificado.data?.tokens?.accessToken;
  prueba('Verificación de OTP y entrega de tokens', () => {
    assert.equal(verificado.code, 200);
    assert.ok(token, 'no llegó el access token');
    assert.equal(verificado.data.nextStep, 'pin_setup');
  });

  const pin = await invocar(evento('POST', '/api/v1/auth/pin', {
    body: { pin: '284913', confirmPin: '284913' }, token,
  }));
  prueba('Configuración del PIN', () => {
    assert.equal(pin.code, 200);
    assert.equal(pin.data.nextStep, 'kyc');
  });

  seccion('3. Subida multipart codificada en base64');

  const formulario = new FormData();
  formulario.set('documentType', 'national_id');
  formulario.set('documentNumber', 'V-24556113');
  formulario.set('birthDate', '1994-07-12');
  formulario.set('documentFront', new File([PNG], 'frente.png', { type: 'image/png' }));
  formulario.set('documentBack', new File([PNG], 'reverso.png', { type: 'image/png' }));
  formulario.set('selfie', new File([PNG], 'selfie.png', { type: 'image/png' }));
  const peticion = new Request('https://demo.netlify.app/api/v1/kyc/submit', { method: 'POST', body: formulario });
  const binario = Buffer.from(await peticion.arrayBuffer());

  const envio = await invocar({
    httpMethod: 'POST',
    path: '/api/v1/kyc/submit',
    headers: {
      host: 'demo.netlify.app',
      'x-nf-client-connection-ip': '198.51.100.7',
      'content-type': peticion.headers.get('content-type'),
      authorization: `Bearer ${token}`,
    },
    body: binario.toString('base64'),
    isBase64Encoded: true,
  });
  prueba('El KYC acepta los 3 ficheros llegados en base64', () => {
    assert.equal(envio.code, 201);
    assert.equal(envio.data.submission.status, 'in_review');
  });
  prueba('El número de documento se devuelve enmascarado', () => {
    assert.equal(envio.data.submission.documentNumber, '****6113');
  });

  seccion('4. Auto-revisión sin temporizadores');

  const inmediato = await invocar(evento('GET', '/api/v1/kyc/status', { token }));
  prueba('Justo después del envío sigue en revisión', () => {
    assert.equal(inmediato.data.kycStatus, 'in_review');
  });

  await new Promise((s) => setTimeout(s, 1400));
  const despues = await invocar(evento('GET', '/api/v1/kyc/status', { token }));
  prueba('Pasado el plazo, la consulta resuelve el expediente (no hace falta setTimeout)', () => {
    assert.equal(despues.data.kycStatus, 'approved');
    assert.equal(despues.data.kycLevel, 1);
    assert.equal(despues.data.limits.perTransaction, 1000);
    assert.equal(despues.data.nextStep, 'home');
  });

  seccion('5. Identidad del cliente sin socket');

  const actividad = await invocar(evento('GET', '/api/v1/auth/sessions', { token }));
  prueba('La auditoría guarda la IP de la cabecera de Netlify, no "undefined"', () => {
    assert.equal(actividad.code, 200);
    const ips = actividad.data.recentActivity.map((a) => a.ip);
    assert.ok(ips.includes('198.51.100.7'), `IPs registradas: ${JSON.stringify(ips.slice(0, 3))}`);
  });

  console.log('\n──────────────────────────────────────────────────────────');
  console.log(`  \x1b[32m${superadas} pruebas superadas\x1b[0m  ·  ${
    fallos ? `\x1b[31m${fallos} fallidas\x1b[0m` : '0 fallidas'}  ·  ${superadas + fallos} totales`);
  console.log('──────────────────────────────────────────────────────────\n');

  await close();
  process.exitCode = fallos ? 1 : 0;
})().catch(async (err) => {
  console.error('\n✘ Error inesperado:', err);
  await close().catch(() => {});
  process.exit(1);
});
