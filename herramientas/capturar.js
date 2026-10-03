/**
 * Recorre el módulo de inicio en un navegador real y captura cada pantalla.
 * Pilota la app Flutter a través de su árbol de semántica (accesibilidad),
 * igual que lo haría un lector de pantalla.
 *
 *   PLAYWRIGHT_BROWSERS_PATH=/var/tmp/pw node capturar.js
 */
const { chromium } = require('playwright-core');
const fs = require('node:fs');
const path = require('node:path');

const BASE = process.env.APP_URL || 'http://localhost:4000';
const OUT = path.resolve('/home/user/remesas-app/capturas');
const MUESTRAS = path.resolve('/home/user/tools/muestras');
const VIEWPORT = { width: 400, height: 860 };

fs.mkdirSync(OUT, { recursive: true });
for (const f of fs.readdirSync(OUT)) fs.unlinkSync(path.join(OUT, f));

let n = 0;
const pasos = [];

async function shot(page, nombre, etiqueta) {
  n++;
  const archivo = `${String(n).padStart(2, '0')}-${nombre}.png`;
  await page.screenshot({ path: path.join(OUT, archivo) });
  pasos.push({ archivo, etiqueta });
  console.log(`  📸 ${String(n).padStart(2, '0')} · ${etiqueta}`);
}

async function esperarTexto(page, texto, timeout = 20000) {
  await page.waitForFunction((t) => document.body.innerText.includes(t), texto, { timeout });
  await page.waitForTimeout(500);
}

/**
 * Pulsa el nodo semántico más pequeño que contenga el texto, dando prioridad
 * a los que son pulsables (flt-tappable / role=button).
 */
async function pulsar(page, texto, { exacto = false, pausa = 750 } = {}) {
  const objetivo = await page.evaluate(({ texto, exacto }) => {
    const nodos = [...document.querySelectorAll('flt-semantics')];
    const visible = (r) => r.width > 2 && r.height > 2;
    const area = (r) => r.width * r.height;

    // 1. El nodo más pequeño que contiene el texto buscado.
    let etiqueta = null;
    let menor = Infinity;
    for (const el of nodos) {
      const t = (el.textContent || '').trim();
      if (exacto ? t !== texto : !t.includes(texto)) continue;
      const r = el.getBoundingClientRect();
      if (!visible(r) || area(r) >= menor) continue;
      menor = area(r);
      etiqueta = el;
    }
    if (!etiqueta) return null;
    const re = etiqueta.getBoundingClientRect();
    const cx = re.x + re.width / 2;
    const cy = re.y + re.height / 2;

    // 2. El nodo pulsable más pequeño que cubre ese punto
    //    (en Flutter el gesto y el rótulo suelen ser nodos distintos).
    const lienzo = window.innerWidth * window.innerHeight;
    let pulsable = null;
    let mejor = Infinity;
    for (const el of nodos) {
      if (!el.hasAttribute('flt-tappable')) continue;
      const r = el.getBoundingClientRect();
      if (!visible(r) || area(r) > lienzo * 0.6) continue;
      if (cx < r.x || cx > r.x + r.width || cy < r.y || cy > r.y + r.height) continue;
      if (area(r) >= mejor) continue;
      mejor = area(r);
      pulsable = el;
    }

    const elegido = pulsable || etiqueta;
    if (!elegido.id) elegido.id = `pw-${Math.random().toString(36).slice(2)}`;
    const rg = elegido.getBoundingClientRect();
    return { id: elegido.id, dx: cx - rg.x, dy: cy - rg.y, pulsable: !!pulsable };
  }, { texto, exacto });

  if (!objetivo) throw new Error(`No encuentro el elemento «${texto}»`);
  await page.locator(`#${objetivo.id}`).click({
    timeout: 8000,
    position: { x: objetivo.dx, y: objetivo.dy },
  });
  await page.waitForTimeout(pausa);
}

const campos = (page) => page.locator('input[data-semantics-role="text-field"]');

/** Escribe en el enésimo campo de texto de la pantalla actual. */
async function escribir(page, indice, valor) {
  const campo = campos(page).nth(indice);
  await campo.click({ timeout: 8000 });
  await campo.fill('');
  await campo.type(valor, { delay: 25 });
  await page.waitForTimeout(350);
}

/** Adjunta un fichero al próximo selector que abra la app. */
async function adjuntar(page, accion, fichero) {
  const espera = page.waitForEvent('filechooser', { timeout: 15000 });
  await accion();
  const chooser = await espera;
  await chooser.setFiles(fichero);
  await page.waitForTimeout(1400);
}

(async () => {
  console.log('\n🎬 Recorriendo el módulo de inicio...\n');
  const browser = await chromium.launch({
    args: ['--no-sandbox', '--disable-dev-shm-usage',
           '--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream'],
  });
  const contexto = await browser.newContext({
    viewport: VIEWPORT,
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true,
    locale: 'es-VE',
  });
  const page = await contexto.newPage();
  global.__page = page;

  // ─────────── Splash ───────────
  await page.goto(BASE, { waitUntil: 'commit', timeout: 60000 });
  // El splash se mantiene 1,1 s y su animación sigue viva: hay que disparar
  // la captura mientras se pintan fotogramas, o CanvasKit devuelve el siguiente.
  await page.waitForTimeout(900);
  await shot(page, 'splash', 'Splash · arranque y restauración de sesión');

  // ─────────── Onboarding ───────────
  await esperarTexto(page, 'Llega en minutos');
  await shot(page, 'onboarding-1', 'Bienvenida 1 · Llega en minutos');
  await pulsar(page, 'Siguiente');
  await shot(page, 'onboarding-2', 'Bienvenida 2 · Tarifas transparentes');
  await pulsar(page, 'Siguiente');
  await shot(page, 'onboarding-3', 'Bienvenida 3 · Seguridad bancaria');

  // ─────────── Login ───────────
  await pulsar(page, 'Ya tengo una cuenta');
  await esperarTexto(page, 'Hola de nuevo');
  await shot(page, 'login', 'Inicio de sesión');

  // ─────────── Recuperar contraseña ───────────
  await pulsar(page, '¿Olvidaste');
  await page.waitForTimeout(900);
  await shot(page, 'recuperar', 'Recuperar contraseña · envío del enlace');
  await pulsar(page, 'Volver');
  await page.waitForTimeout(900);

  // ─────────── Registro ───────────
  await pulsar(page, 'Regístrate');
  await esperarTexto(page, 'Crea tu cuenta');
  await shot(page, 'registro-vacio', 'Registro · formulario limpio');

  const correo = `maria.demo.${Date.now().toString().slice(-6)}@remesas.app`;
  const telefono = `412${String(Date.now()).slice(-7)}`.slice(0, 10);

  await escribir(page, 0, 'María');
  await escribir(page, 1, 'González');
  await escribir(page, 2, correo);
  await escribir(page, 3, telefono);
  await escribir(page, 4, '123456');          // contraseña débil → medidor rojo
  await page.waitForTimeout(600);
  await shot(page, 'registro-debil', 'Registro · contraseña débil (medidor en rojo)');

  await escribir(page, 4, 'Remesas2026$Seg');  // contraseña fuerte → medidor verde
  await page.waitForTimeout(600);

  // La casilla de términos queda bajo el pliegue: hay que desplazarse.
  await page.mouse.wheel(0, 340);
  await page.waitForTimeout(800);
  const casilla = page.locator('flt-semantics[role="checkbox"]').first();
  if (await casilla.count()) {
    await casilla.click({ timeout: 8000 });
  } else {
    await pulsar(page, 'Acepto');
  }
  await page.waitForTimeout(500);
  await shot(page, 'registro-lleno', 'Registro · validado y términos aceptados');

  await pulsar(page, 'Continuar', { pausa: 2500 });

  // ─────────── OTP ───────────
  await esperarTexto(page, 'Verifica tu número');
  await shot(page, 'otp', 'Verificación OTP · código de demostración visible');

  // Código erróneo → estado de error
  await escribir(page, 0, '0');
  for (const d of '00000'.split('')) {
    await page.keyboard.type(d, { delay: 90 });
  }
  await page.waitForTimeout(1800);
  await shot(page, 'otp-error', 'OTP incorrecto · casillas en rojo');

  // Código bueno mediante el botón «Usar» del modo demo
  await pulsar(page, 'Usar', { pausa: 3000 });

  // ─────────── PIN ───────────
  await esperarTexto(page, 'Crea tu PIN');
  await shot(page, 'pin-vacio', 'PIN · creación');
  for (const d of '2849'.split('')) await pulsar(page, d, { exacto: true, pausa: 220 });
  await shot(page, 'pin-escribiendo', 'PIN · puntos rellenándose');
  for (const d of '13'.split('')) await pulsar(page, d, { exacto: true, pausa: 220 });
  await esperarTexto(page, 'Confirma tu PIN');
  await shot(page, 'pin-confirmar', 'PIN · confirmación');
  for (const d of '284913'.split('')) await pulsar(page, d, { exacto: true, pausa: 220 });
  await page.waitForTimeout(2600);

  // ─────────── Biometría (si aparece) ───────────
  const hayBiometria = await page.evaluate(() =>
    document.body.innerText.includes('biometr') || document.body.innerText.includes('Biometr'));
  if (hayBiometria) {
    await shot(page, 'biometria', 'Biometría · activación opcional');
    for (const t of ['Ahora no', 'Omitir', 'Continuar']) {
      try { await pulsar(page, t, { pausa: 2200 }); break; } catch { /* siguiente */ }
    }
  }

  // ─────────── KYC ───────────
  await esperarTexto(page, 'documento te identificas');
  await shot(page, 'kyc-1', 'KYC 1 · tipo y número de documento');

  await escribir(page, 0, 'V-24556113');
  await escribir(page, 1, '1994-03-18');
  await page.waitForTimeout(400);
  await shot(page, 'kyc-1-lleno', 'KYC 1 · datos completados');
  await pulsar(page, 'Continuar', { pausa: 1000 });

  await esperarTexto(page, 'Frente del documento');
  await shot(page, 'kyc-2', 'KYC 2 · captura del documento');

  await adjuntar(page, () => pulsar(page, 'Frente del documento', { pausa: 300 }),
    path.join(MUESTRAS, 'documento-frente.jpg'));
  await adjuntar(page, () => pulsar(page, 'Reverso del documento', { pausa: 300 }),
    path.join(MUESTRAS, 'documento-reverso.jpg'));
  await page.waitForTimeout(800);
  await shot(page, 'kyc-2-lleno', 'KYC 2 · ambas caras cargadas');
  await pulsar(page, 'Continuar', { pausa: 1000 });

  await esperarTexto(page, 'Tómate una selfie');
  await shot(page, 'kyc-3', 'KYC 3 · selfie');

  // El círculo de la cámara es un GestureDetector sin texto: lo busco por tamaño.
  const circulo = async () => {
    const id = await page.evaluate(() => {
      const el = [...document.querySelectorAll('flt-semantics[flt-tappable]')].find((e) => {
        const r = e.getBoundingClientRect();
        return Math.abs(r.height - 190) < 10 && r.width > 100;
      });
      if (!el) return null;
      if (!el.id) el.id = `pw-${Math.random().toString(36).slice(2)}`;
      return el.id;
    });
    if (id) {
      await page.locator(`#${id}`).click({ timeout: 8000 });
    } else {
      // Plan B: pulsar 110 px por encima del rótulo.
      const caja = await page.evaluate(() => {
        const el = [...document.querySelectorAll('flt-semantics')]
          .find((e) => (e.textContent || '').includes('Toca el círculo'));
        const r = el.getBoundingClientRect();
        return { x: r.x + r.width / 2, y: r.y };
      });
      await page.mouse.click(caja.x, caja.y - 110);
    }
  };
  await adjuntar(page, circulo, path.join(MUESTRAS, 'selfie.jpg'));
  await shot(page, 'kyc-3-lleno', 'KYC 3 · selfie capturada');

  await pulsar(page, 'Enviar verificación', { pausa: 3000 });

  // ─────────── Revisión + aprobación automática ───────────
  try {
    await esperarTexto(page, 'Estamos revisando', 15000);
    await shot(page, 'kyc-revision', 'KYC · en revisión (se aprueba sola en 10 s)');
  } catch { /* puede aprobarse muy rápido */ }

  await esperarTexto(page, 'Disponible para enviar', 45000);
  await page.waitForTimeout(1500);
  await shot(page, 'inicio', 'Inicio · sesión verificada y límites KYC');

  // ─────────── Bloqueo por PIN ───────────
  try {
    await pulsar(page, 'Bloquear', { pausa: 2000 });
    await shot(page, 'desbloquear', 'Desbloqueo con PIN tras la inactividad');
    for (const d of '284913'.split('')) await pulsar(page, d, { exacto: true, pausa: 200 });
    await page.waitForTimeout(2200);
    await shot(page, 'inicio-2', 'Inicio · de vuelta tras desbloquear');
  } catch (e) {
    console.log('    (sin botón de bloqueo visible:', e.message.slice(0, 60), ')');
  }

  console.log('\n✔ Recorrido completado\n');
  fs.writeFileSync(path.join(OUT, 'indice.json'), JSON.stringify(pasos, null, 2));
  await browser.close();
})().catch(async (err) => {
  console.error('\n💥 Error:', err.message.slice(0, 300));
  const page = global.__page;
  if (page) {
    try {
      await page.screenshot({ path: path.join(OUT, '_fallo.png') });
      const txt = await page.evaluate(() => document.body.innerText.replace(/\n+/g, ' | ').slice(0, 600));
      console.error('   pantalla:', txt);
    } catch { /* nada */ }
  }
  process.exit(1);
});
