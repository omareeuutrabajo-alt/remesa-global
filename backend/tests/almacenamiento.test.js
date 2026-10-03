#!/usr/bin/env node
'use strict';
/**
 * Pruebas del driver de Supabase Storage contra un emulador local.
 *
 * El almacenamiento en la nube es el único tramo del backend que en
 * desarrollo nunca se ejecuta: en local siempre gana el driver de disco. Sin
 * esto, el primer envío de KYC en producción sería la primera vez que ese
 * código corre. Aquí se levanta un servidor que habla el dialecto de la API
 * de Supabase Storage y se comprueba el contrato completo.
 *
 *   node tests/almacenamiento.test.js
 */
const http = require('node:http');
const assert = require('node:assert');

const PUERTO = 5599;
const CLAVE = 'clave_de_servicio_de_prueba';
const objetos = new Map();
const peticiones = [];
let bucketCreado = null;

const servidor = http.createServer((req, res) => {
  const trozos = [];
  req.on('data', (c) => trozos.push(c));
  req.on('end', () => {
    const cuerpo = Buffer.concat(trozos);
    const autorizado = req.headers.authorization === `Bearer ${CLAVE}` && req.headers.apikey === CLAVE;
    peticiones.push({ metodo: req.method, url: req.url, autorizado, tipo: req.headers['content-type'] });
    const responder = (code, obj) => {
      res.writeHead(code, { 'content-type': 'application/json' });
      res.end(JSON.stringify(obj));
    };

    if (!autorizado) return responder(401, { message: 'no autorizado' });

    if (req.method === 'POST' && req.url === '/storage/v1/bucket') {
      const b = JSON.parse(cuerpo);
      if (bucketCreado) return responder(409, { message: 'ya existe' });
      bucketCreado = b;
      return responder(200, { name: b.name });
    }
    if (req.method === 'POST' && req.url.startsWith('/storage/v1/object/list/')) {
      const { prefix } = JSON.parse(cuerpo);
      return responder(200, [...objetos.keys()]
        .filter((k) => k.startsWith(`${prefix}/`))
        .map((k) => ({ name: k.slice(prefix.length + 1) })));
    }
    if (req.method === 'POST' && req.url.startsWith('/storage/v1/object/sign/')) {
      const ruta = req.url.replace('/storage/v1/object/sign/kyc/', '');
      if (!objetos.has(ruta)) return responder(404, { message: 'no existe' });
      const { expiresIn } = JSON.parse(cuerpo);
      return responder(200, { signedURL: `/object/sign/kyc/${ruta}?token=jwt.firmado&exp=${expiresIn}` });
    }
    if (req.method === 'DELETE' && req.url === '/storage/v1/object/kyc') {
      const { prefixes } = JSON.parse(cuerpo);
      prefixes.forEach((p) => objetos.delete(p));
      return responder(200, prefixes.map((name) => ({ name })));
    }
    if (req.method === 'POST' && req.url.startsWith('/storage/v1/object/kyc/')) {
      objetos.set(req.url.replace('/storage/v1/object/kyc/', ''), cuerpo);
      return responder(200, { Key: req.url.replace('/storage/v1/object/', '') });
    }
    responder(404, { message: `ruta desconocida ${req.url}` });
  });
});

const verde = (t) => `\x1b[32m✔\x1b[0m ${t}`;
let fallos = 0;
function prueba(nombre, fn) {
  try { fn(); console.log('  ' + verde(nombre)); } catch (err) {
    fallos++; console.log(`  \x1b[31m✘\x1b[0m ${nombre}\n      ${err.message}`);
  }
}

servidor.listen(PUERTO, '127.0.0.1', async () => {
  process.env.SUPABASE_URL = `http://127.0.0.1:${PUERTO}`;
  process.env.SUPABASE_SERVICE_ROLE_KEY = CLAVE;
  process.env.SUPABASE_KYC_BUCKET = 'kyc';
  delete process.env.STORAGE_DRIVER;

  const almacen = require('../src/services/storageService');
  const foto = { buffer: Buffer.from('bytes-de-la-foto'), mimetype: 'image/png', originalname: 'frente.png' };

  console.log('\n\x1b[36mAlmacenamiento de documentos · driver Supabase\x1b[0m');

  prueba('Elige Supabase cuando hay credenciales', () => assert.equal(almacen.driver, 'supabase'));

  const frente = await almacen.guardar({ userId: 'usuario-7', campo: 'documentFront', fichero: foto });
  const selfie = await almacen.guardar({ userId: 'usuario-7', campo: 'selfie', fichero: foto });

  prueba('Sube el documento y devuelve su ruta relativa', () => {
    assert.match(frente, /^usuario-7\/documentFront-\d+-[0-9a-f]{8}\.png$/);
    assert.ok(objetos.has(frente), 'el objeto no llegó al almacén');
  });
  prueba('Aísla los ficheros por usuario', () => {
    assert.ok(frente.startsWith('usuario-7/') && selfie.startsWith('usuario-7/'));
  });
  prueba('Nombres irrepetibles: dos subidas no se pisan', () => assert.notEqual(frente, selfie));
  prueba('Crea el bucket como PRIVADO', () => {
    assert.equal(bucketCreado.public, false);
    assert.deepEqual(bucketCreado.allowed_mime_types.sort(), ['image/heic', 'image/jpeg', 'image/png', 'image/webp']);
  });
  prueba('Sólo intenta crear el bucket una vez', () => {
    assert.equal(peticiones.filter((p) => p.url === '/storage/v1/bucket').length, 1);
  });
  prueba('Envía el tipo MIME real del fichero', () => {
    assert.equal(peticiones.find((p) => p.url.includes('documentFront')).tipo, 'image/png');
  });
  prueba('Autentica con la clave de servicio en cada llamada', () => {
    assert.ok(peticiones.every((p) => p.autorizado));
  });

  const url = await almacen.urlFirmada(frente, 300);
  prueba('La URL firmada caduca y no es pública', () => {
    assert.ok(url.includes('token='), 'falta el token de firma');
    assert.ok(url.includes('exp=300'), 'falta la caducidad');
    assert.ok(url.startsWith(`http://127.0.0.1:${PUERTO}/storage/v1`), `URL inesperada: ${url}`);
  });
  prueba('Devuelve null si no hay ruta (documento opcional)', async () => {
    assert.equal(await almacen.urlFirmada(null), null);
  });

  await almacen.purgar('usuario-7');
  prueba('Purgar borra todos los ficheros del usuario (derecho al olvido)', () => {
    assert.equal([...objetos.keys()].filter((k) => k.startsWith('usuario-7/')).length, 0);
  });

  console.log(`\n  ${fallos ? `\x1b[31m${fallos} fallidas\x1b[0m` : '\x1b[32mTodas las pruebas superadas\x1b[0m'}\n`);
  servidor.close();
  process.exitCode = fallos ? 1 : 0;
});
