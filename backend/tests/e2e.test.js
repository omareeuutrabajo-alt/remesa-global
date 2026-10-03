'use strict';
/**
 * Prueba de extremo a extremo del módulo de inicio.
 * Recorre el flujo real que hará la app Flutter:
 *   registro → OTP → PIN → KYC → biometría → refresh → login.
 *
 * Uso:  node tests/e2e.test.js    (con el servidor levantado en :4000)
 */

const BASE = process.env.API_URL || 'http://localhost:4000';
const API = `${BASE}/api/v1`;

const c = {
  green: (s) => `\x1b[32m${s}\x1b[0m`,
  red: (s) => `\x1b[31m${s}\x1b[0m`,
  dim: (s) => `\x1b[2m${s}\x1b[0m`,
  cyan: (s) => `\x1b[36m${s}\x1b[0m`,
  bold: (s) => `\x1b[1m${s}\x1b[0m`,
};

let passed = 0;
let failed = 0;

function check(label, condition, extra = '') {
  if (condition) {
    passed++;
    console.log(`  ${c.green('✔')} ${label}${extra ? c.dim(` — ${extra}`) : ''}`);
  } else {
    failed++;
    console.log(`  ${c.red('✘')} ${label}${extra ? c.dim(` — ${extra}`) : ''}`);
  }
}

async function call(method, path, { body, token, form } = {}) {
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body) headers['Content-Type'] = 'application/json';
  const res = await fetch(`${API}${path}`, {
    method,
    headers,
    body: form ?? (body ? JSON.stringify(body) : undefined),
  });
  const json = await res.json().catch(() => ({}));
  return { status: res.status, ...json };
}

/** PNG 1x1 válido para simular la captura de documento/selfie. */
function fakeImage(name) {
  const png = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    'base64',
  );
  return new File([png], name, { type: 'image/png' });
}

const stamp = Date.now();
const usuario = {
  firstName: 'María',
  lastName: 'González',
  email: `maria.test.${stamp}@remesas.app`,
  phone: `+5841${String(stamp).slice(-8)}`,
  countryCode: 'VE',
  password: 'Remesas2026$Seg',
  acceptedTerms: true,
};
const DEVICE = { deviceId: `device-test-${stamp}`, deviceName: 'Pixel 8 Pro', platform: 'android' };

(async function run() {
  console.log(c.bold('\n╔══════════════════════════════════════════════════════════╗'));
  console.log(c.bold('║   Pruebas E2E · Módulo de inicio · App de remesas        ║'));
  console.log(c.bold('╚══════════════════════════════════════════════════════════╝\n'));

  // ─────────────── 1. Salud del servicio ───────────────
  console.log(c.cyan('1. Salud del servicio'));
  const health = await fetch(`${BASE}/health`).then((r) => r.json());
  check('GET /health responde ok', health?.data?.status === 'ok');

  // ─────────────── 2. Registro ───────────────
  console.log(c.cyan('\n2. Registro de usuario'));
  const weak = await call('POST', '/auth/register', { body: { ...usuario, password: '12345678' } });
  check('Rechaza contraseña débil', weak.status === 400, weak.error?.code);

  const badEmail = await call('POST', '/auth/register', { body: { ...usuario, email: 'no-es-correo' } });
  check('Rechaza correo inválido', badEmail.status === 400, badEmail.error?.details?.[0]?.message);

  const sinTerminos = await call('POST', '/auth/register', { body: { ...usuario, acceptedTerms: false } });
  check('Exige aceptar términos', sinTerminos.status === 400);

  const reg = await call('POST', '/auth/register', { body: usuario });
  check('Registro exitoso (201)', reg.status === 201, `challenge=${reg.data?.challengeId?.slice(0, 8)}…`);
  check('Enmascara el teléfono', /\*{3}/.test(reg.data?.maskedPhone || ''), reg.data?.maskedPhone);
  check('Entrega OTP de desarrollo', /^\d{6}$/.test(reg.data?.devCode || ''), reg.data?.devCode);

  const dup = await call('POST', '/auth/register', { body: usuario });
  check('Impide correo duplicado', dup.status === 409, dup.error?.code);

  // ─────────────── 3. Verificación OTP ───────────────
  console.log(c.cyan('\n3. Verificación por OTP'));
  const otpMal = await call('POST', '/auth/otp/verify', {
    body: { challengeId: reg.data.challengeId, code: '000000', ...DEVICE },
  });
  check('Rechaza código incorrecto', otpMal.status === 400, `intentos restantes: ${otpMal.error?.details?.attemptsLeft}`);

  const verify = await call('POST', '/auth/otp/verify', {
    body: { challengeId: reg.data.challengeId, code: reg.data.devCode, ...DEVICE },
  });
  check('Verifica OTP y emite tokens', !!verify.data?.tokens?.accessToken);
  check('Cuenta queda activa', verify.data?.user?.status === 'active');
  check('Siguiente paso = pin_setup', verify.data?.nextStep === 'pin_setup', verify.data?.nextStep);

  const reuse = await call('POST', '/auth/otp/verify', {
    body: { challengeId: reg.data.challengeId, code: reg.data.devCode, ...DEVICE },
  });
  check('No permite reusar el OTP', reuse.status === 400, reuse.error?.code);

  let { accessToken, refreshToken } = verify.data.tokens;

  // ─────────────── 4. Sesión ───────────────
  console.log(c.cyan('\n4. Sesión autenticada'));
  const me = await call('GET', '/auth/me', { token: accessToken });
  check('GET /auth/me devuelve el perfil', me.data?.user?.email === usuario.email);
  check('No expone hashes', !JSON.stringify(me.data).includes('password_hash'));

  const sinToken = await call('GET', '/auth/me');
  check('Bloquea acceso sin token', sinToken.status === 401, sinToken.error?.code);

  const tokenMalo = await call('GET', '/auth/me', { token: 'token.falso.aqui' });
  check('Bloquea token inválido', tokenMalo.status === 401, tokenMalo.error?.code);

  // ─────────────── 5. PIN ───────────────
  console.log(c.cyan('\n5. PIN de 6 dígitos'));
  const pinDebil = await call('POST', '/auth/pin', { token: accessToken, body: { pin: '123456', confirmPin: '123456' } });
  check('Rechaza PIN común (123456)', pinDebil.status === 400, pinDebil.error?.code);

  const pinNoCoincide = await call('POST', '/auth/pin', { token: accessToken, body: { pin: '284913', confirmPin: '284914' } });
  check('Exige confirmación coincidente', pinNoCoincide.status === 400);

  const pinOk = await call('POST', '/auth/pin', { token: accessToken, body: { pin: '284913', confirmPin: '284913' } });
  check('Configura el PIN', pinOk.status === 200, `nextStep=${pinOk.data?.nextStep}`);

  const pinMal = await call('POST', '/auth/pin/verify', { token: accessToken, body: { pin: '999999' } });
  check('Detecta PIN incorrecto', pinMal.status === 401, `restantes: ${pinMal.error?.details?.attemptsLeft}`);

  const pinBien = await call('POST', '/auth/pin/verify', { token: accessToken, body: { pin: '284913' } });
  check('Valida PIN correcto', pinBien.data?.verified === true);

  // ─────────────── 6. KYC ───────────────
  console.log(c.cyan('\n6. Verificación de identidad (KYC)'));
  const estadoInicial = await call('GET', '/kyc/status', { token: accessToken });
  check('Estado inicial = not_started', estadoInicial.data?.kycStatus === 'not_started');
  check('Límite inicial = 0 USD', estadoInicial.data?.limits?.perTransaction === 0);

  const fd = new FormData();
  fd.append('documentType', 'national_id');
  fd.append('documentNumber', 'V-24.556.113');
  fd.append('birthDate', '1994-05-18');
  fd.append('documentFront', fakeImage('frente.png'));
  fd.append('documentBack', fakeImage('reverso.png'));
  fd.append('selfie', fakeImage('selfie.png'));
  const envioKyc = await call('POST', '/kyc/submit', { token: accessToken, form: fd });
  check('Acepta el expediente KYC', envioKyc.status === 201, envioKyc.data?.submission?.status);
  check('Enmascara el número de documento', /^\*{4}/.test(envioKyc.data?.submission?.documentNumber || ''),
    envioKyc.data?.submission?.documentNumber);

  const revision = await call('POST', '/kyc/_simulate-review', { token: accessToken, body: { approved: true } });
  check('Aprueba la verificación', revision.data?.status === 'approved');

  const estadoFinal = await call('GET', '/kyc/status', { token: accessToken });
  check('Nivel KYC = 1', estadoFinal.data?.kycLevel === 1);
  check('Límites desbloqueados', estadoFinal.data?.limits?.perTransaction === 1000,
    `${estadoFinal.data?.limits?.perTransaction} USD/transacción`);
  check('Siguiente paso = home', estadoFinal.data?.nextStep === 'home');

  // ─────────────── 7. Rotación de tokens ───────────────
  console.log(c.cyan('\n7. Rotación de refresh token'));
  const viejo = refreshToken;
  const refrescado = await call('POST', '/auth/refresh', { body: { refreshToken } });
  check('Emite un par nuevo', !!refrescado.data?.tokens?.refreshToken);
  check('El refresh token cambia (rotación)', refrescado.data.tokens.refreshToken !== viejo);
  refreshToken = refrescado.data.tokens.refreshToken;
  accessToken = refrescado.data.tokens.accessToken;

  const reusoRefresh = await call('POST', '/auth/refresh', { body: { refreshToken: viejo } });
  check('Detecta reuso de token robado', reusoRefresh.status === 401, reusoRefresh.error?.code);

  const traRevocacion = await call('POST', '/auth/refresh', { body: { refreshToken } });
  check('Revoca todas las sesiones tras el reuso', traRevocacion.status === 401, traRevocacion.error?.code);

  // ─────────────── 8. Login con dispositivo de confianza ───────────────
  console.log(c.cyan('\n8. Inicio de sesión'));
  const malPass = await call('POST', '/auth/login', {
    body: { email: usuario.email, password: 'ClaveIncorrecta1$', ...DEVICE },
  });
  check('Rechaza contraseña incorrecta', malPass.status === 401, `restantes: ${malPass.error?.details?.attemptsLeft}`);

  const noExiste = await call('POST', '/auth/login', {
    body: { email: `fantasma.${stamp}@remesas.app`, password: 'Loquesea1$', ...DEVICE },
  });
  check('No revela si el correo existe', noExiste.error?.code === 'INVALID_CREDENTIALS', noExiste.error?.code);

  const login = await call('POST', '/auth/login', {
    body: { email: usuario.email, password: usuario.password, ...DEVICE },
  });
  check('Dispositivo de confianza omite el OTP', login.data?.requiresOtp === false);
  check('Devuelve tokens válidos', !!login.data?.tokens?.accessToken);
  check('Siguiente paso = home', login.data?.nextStep === 'home');
  accessToken = login.data.tokens.accessToken;
  refreshToken = login.data.tokens.refreshToken;

  const otroDispositivo = await call('POST', '/auth/login', {
    body: { email: usuario.email, password: usuario.password, deviceId: `otro-${stamp}`, platform: 'ios' },
  });
  check('Dispositivo nuevo exige OTP (2FA)', otroDispositivo.data?.requiresOtp === true);

  // ─────────────── 9. Biometría ───────────────
  console.log(c.cyan('\n9. Biometría'));
  const enroll = await call('POST', '/auth/biometric/enroll', { token: accessToken, body: DEVICE });
  check('Registra la biometría del dispositivo', !!enroll.data?.biometricToken);

  const bioMal = await call('POST', '/auth/biometric/login', {
    body: { deviceId: DEVICE.deviceId, biometricToken: 'a'.repeat(64) },
  });
  check('Rechaza token biométrico falso', bioMal.status === 401, bioMal.error?.code);

  const bioLogin = await call('POST', '/auth/biometric/login', {
    body: { deviceId: DEVICE.deviceId, biometricToken: enroll.data.biometricToken },
  });
  check('Inicia sesión con biometría', !!bioLogin.data?.tokens?.accessToken);

  // ─────────────── 10. Recuperación de contraseña ───────────────
  console.log(c.cyan('\n10. Recuperación de contraseña'));
  const desconocido = await call('POST', '/auth/password/forgot', { body: { email: `nadie.${stamp}@x.com` } });
  check('Respuesta genérica si el correo no existe', desconocido.status === 200 && !desconocido.data?.challengeId);

  const forgot = await call('POST', '/auth/password/forgot', { body: { email: usuario.email } });
  check('Envía OTP de recuperación', !!forgot.data?.challengeId, forgot.data?.maskedEmail);

  const resetOtp = await call('POST', '/auth/otp/verify', {
    body: { challengeId: forgot.data.challengeId, code: forgot.data.devCode, ...DEVICE },
  });
  check('Entrega token de restablecimiento', !!resetOtp.data?.resetToken);

  const mismaClave = await call('POST', '/auth/password/reset', {
    body: { resetToken: resetOtp.data.resetToken, newPassword: usuario.password },
  });
  check('Impide reutilizar la contraseña anterior', mismaClave.status === 400, mismaClave.error?.code);

  const nuevaClave = 'NuevaRemesa2026#';
  const reset = await call('POST', '/auth/password/reset', {
    body: { resetToken: resetOtp.data.resetToken, newPassword: nuevaClave },
  });
  check('Restablece la contraseña', reset.status === 200);

  const loginNuevo = await call('POST', '/auth/login', {
    body: { email: usuario.email, password: nuevaClave, ...DEVICE },
  });
  check('Inicia sesión con la contraseña nueva', !!loginNuevo.data?.tokens?.accessToken);

  // ─────────────── 11. Cierre de sesión ───────────────
  console.log(c.cyan('\n11. Cierre de sesión'));
  const sesiones = await call('GET', '/auth/sessions', { token: loginNuevo.data.tokens.accessToken });
  check('Lista sesiones activas y actividad', Array.isArray(sesiones.data?.sessions),
    `${sesiones.data?.sessions?.length} sesión(es), ${sesiones.data?.recentActivity?.length} eventos`);

  const logout = await call('POST', '/auth/logout', {
    token: loginNuevo.data.tokens.accessToken,
    body: { refreshToken: loginNuevo.data.tokens.refreshToken },
  });
  check('Cierra la sesión', logout.status === 200);

  const trasLogout = await call('POST', '/auth/refresh', { body: { refreshToken: loginNuevo.data.tokens.refreshToken } });
  check('El refresh token queda inutilizable', trasLogout.status === 401, trasLogout.error?.code);

  // ─────────────── Resumen ───────────────
  const total = passed + failed;
  console.log(c.bold('\n──────────────────────────────────────────────────────────'));
  console.log(`  ${c.green(`${passed} pruebas superadas`)}  ·  ${failed ? c.red(`${failed} fallidas`) : '0 fallidas'}  ·  ${total} totales`);
  console.log(c.bold('──────────────────────────────────────────────────────────\n'));
  process.exit(failed ? 1 : 0);
})().catch((err) => {
  console.error(c.red(`\n💥 Error ejecutando las pruebas: ${err.message}`));
  console.error(c.dim('¿Está el servidor levantado?  npm start'));
  process.exit(1);
});
