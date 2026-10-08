#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  Build de Netlify: deja listo mobile/build/web
#
#  1) Si el repositorio ya trae el build web compilado, se usa tal cual
#     (despliegue en ~1 minuto, sin depender del SDK).
#  2) Si no, se descarga el SDK de Flutter —cacheado entre despliegues—
#     y se compila desde el código fuente.
#  3) En ambos casos se escribe la identidad instalable (iconos + manifest)
#     y se publica el catálogo en /catalogo.
# ─────────────────────────────────────────────────────────────
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SALIDA="$RAIZ/mobile/build/web"
VERSION_FLUTTER="${FLUTTER_VERSION:-3.47.6}"
CACHE="${NETLIFY_BUILD_BASE:-/opt/build}/cache"

# ═════════════════════════════════════════════════════════════
#  Identidad de la aplicación instalable (PWA)
#
#  `flutter create` deja el manifest de ejemplo ("remesas_app",
#  "A new Flutter project.") y los iconos con el logo de Flutter. Al
#  instalar la web en el móvil aparecía ese icono genérico. Aquí se
#  dibujan los definitivos —avión de papel blanco sobre el degradado de
#  marca— y se escribe el manifest real. Se generan en tiempo de
#  compilación, sin dependencias y sin versionar binarios.
# ═════════════════════════════════════════════════════════════
marca_pwa() {
  echo "▸ Generando iconos y manifest de marca…"
  local guion
  guion="$(mktemp /tmp/iconos-XXXXXX.js)"
  cat > "$guion" <<'FIN_ICONOS'
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const SALIDA = process.argv[2];
const AZUL = [0x17, 0x57, 0xd6];   // #1757D6
const CIAN = [0x17, 0xb3, 0xe8];   // #17B3E8

// Avión de papel: polígono del icono "send" de Material, girado en diagonal.
const AVION = [[2.01, 21], [23, 12], [2.01, 3], [2, 10], [17, 12], [2, 14]];

function avion(cx, cy, escala, grados) {
  const r = (grados * Math.PI) / 180, cos = Math.cos(r), sin = Math.sin(r);
  return AVION.map(([x, y]) => {
    const px = (x - 12.5) / 24, py = (y - 12) / 24;
    return [cx + (px * cos - py * sin) * escala, cy + (px * sin + py * cos) * escala];
  });
}

// Regla par-impar: cuenta los cruces de un rayo horizontal.
function dentro(poli, x, y) {
  let d = false;
  for (let i = 0, j = poli.length - 1; i < poli.length; j = i++) {
    const [xi, yi] = poli[i], [xj, yj] = poli[j];
    if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) d = !d;
  }
  return d;
}

function enRedondeado(x, y, lado, radio) {
  const cx = Math.min(Math.max(x, radio), lado - radio);
  const cy = Math.min(Math.max(y, radio), lado - radio);
  return (x - cx) ** 2 + (y - cy) ** 2 <= radio * radio;
}

/** Dibuja el icono y devuelve RGBA. `sangre` = sin esquinas (Android maskable). */
function dibujar(lado, sangre) {
  const SS = 4, L = lado * SS;                       // supermuestreo 4×4
  const radio = sangre ? 0 : L * 0.235;
  const nave = avion(L / 2, L / 2, sangre ? L * 0.44 : L * 0.56, -28);
  const rgba = Buffer.alloc(lado * lado * 4);

  for (let py = 0; py < lado; py++) {
    for (let px = 0; px < lado; px++) {
      let sr = 0, sg = 0, sb = 0, sa = 0;
      for (let oy = 0; oy < SS; oy++) {
        for (let ox = 0; ox < SS; ox++) {
          const x = px * SS + ox + 0.5, y = py * SS + oy + 0.5;
          if (radio > 0 && !enRedondeado(x, y, L, radio)) continue;
          const t = Math.min(1, (x / L) * 0.45 + (y / L) * 0.55);
          let r = Math.round(AZUL[0] + (CIAN[0] - AZUL[0]) * t);
          let g = Math.round(AZUL[1] + (CIAN[1] - AZUL[1]) * t);
          let b = Math.round(AZUL[2] + (CIAN[2] - AZUL[2]) * t);
          if (dentro(nave, x, y)) { r = 255; g = 255; b = 255; }
          sr += r; sg += g; sb += b; sa += 255;
        }
      }
      const i = (py * lado + px) * 4, alfa = sa / (SS * SS);
      const cob = sa === 0 ? 1 : sa / 255;           // evita el halo en los bordes
      rgba[i] = Math.round(sr / cob);
      rgba[i + 1] = Math.round(sg / cob);
      rgba[i + 2] = Math.round(sb / cob);
      rgba[i + 3] = Math.round(alfa);
    }
  }
  return rgba;
}

/* ── codificador PNG mínimo (sin dependencias) ── */
function crc32(buf) {
  let tabla = crc32.t;
  if (!tabla) {
    tabla = crc32.t = new Int32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      tabla[n] = c;
    }
  }
  let crc = -1;
  for (let i = 0; i < buf.length; i++) crc = tabla[(crc ^ buf[i]) & 0xff] ^ (crc >>> 8);
  return (crc ^ -1) >>> 0;
}

function trozo(tipo, datos) {
  const largo = Buffer.alloc(4); largo.writeUInt32BE(datos.length, 0);
  const cuerpo = Buffer.concat([Buffer.from(tipo, 'ascii'), datos]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(cuerpo), 0);
  return Buffer.concat([largo, cuerpo, crc]);
}

function png(rgba, lado) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(lado, 0); ihdr.writeUInt32BE(lado, 4);
  ihdr[8] = 8; ihdr[9] = 6;                          // 8 bits, RGBA
  const crudo = Buffer.alloc(lado * (lado * 4 + 1)); // filtro 0 por línea
  for (let y = 0; y < lado; y++) {
    rgba.copy(crudo, y * (lado * 4 + 1) + 1, y * lado * 4, (y + 1) * lado * 4);
  }
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    trozo('IHDR', ihdr),
    trozo('IDAT', zlib.deflateSync(crudo, { level: 9 })),
    trozo('IEND', Buffer.alloc(0)),
  ]);
}

for (const [rel, lado, sangre] of [
  ['icons/Icon-192.png', 192, false],
  ['icons/Icon-512.png', 512, false],
  ['icons/Icon-maskable-192.png', 192, true],
  ['icons/Icon-maskable-512.png', 512, true],
  ['favicon.png', 64, false],
]) {
  const destino = path.join(SALIDA, rel);
  fs.mkdirSync(path.dirname(destino), { recursive: true });
  const buf = png(dibujar(lado, sangre), lado);
  fs.writeFileSync(destino, buf);
  console.log(`  ▸ ${rel} (${(buf.length / 1024).toFixed(1)} kB)`);
}

fs.writeFileSync(path.join(SALIDA, 'manifest.json'), JSON.stringify({
  name: 'RemesaGlobal · Envía dinero a casa',
  short_name: 'RemesaGlobal',
  description: 'Envía dinero a tu familia en minutos. Verificación de identidad, PIN y acceso biométrico.',
  start_url: '.',
  scope: '.',
  display: 'standalone',
  orientation: 'portrait-primary',
  background_color: '#F6F8FC',
  theme_color: '#1757D6',
  lang: 'es',
  dir: 'ltr',
  categories: ['finance'],
  prefer_related_applications: false,
  icons: [
    { src: 'icons/Icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any' },
    { src: 'icons/Icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any' },
    { src: 'icons/Icon-maskable-192.png', sizes: '192x192', type: 'image/png', purpose: 'maskable' },
    { src: 'icons/Icon-maskable-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
  ],
}, null, 2));
console.log('  ▸ manifest.json (RemesaGlobal)');
FIN_ICONOS
  node "$guion" "$SALIDA"
  rm -f "$guion"

  # El theme-color de index.html lo escribe Flutter desde la plantilla web:
  # se alinea con el del manifest para que la barra de estado no parpadee.
  if [ -f "$SALIDA/index.html" ]; then
    sed -i 's/<meta name="theme-color" content="[^"]*">/<meta name="theme-color" content="#1757D6">/' \
      "$SALIDA/index.html" || true
  fi
}

# ═════════════════════════════════════════════════════════════
#  Service worker propio
#
#  Flutter 3.47 ya no trae uno útil: su flutter_service_worker.js se
#  desregistra a sí mismo en cuanto se activa y no tiene manejador `fetch`.
#  Chrome en Android exige exactamente eso —un service worker registrado y
#  con manejador fetch— para ofrecer «Instalar aplicación»; sin él solo
#  permite crear un acceso directo, que es un enlace y no una app.
#
#  Se sobrescribe ese mismo archivo en lugar de añadir otro: así lo registra
#  el propio cargador de Flutter y no hay dos service workers peleándose por
#  el mismo ámbito. Estrategia: la red manda; la caché solo responde si la
#  red falla (modo avión, metro, cobertura mala).
# ═════════════════════════════════════════════════════════════
service_worker() {
  local destino="$SALIDA/flutter_service_worker.js"
  [ -f "$destino" ] || return 0
  local version="${COMMIT_REF:-local}-$(date -u +%Y%m%d%H%M%S)"

  echo "▸ Escribiendo service worker (versión $version)…"
  cat > "$destino" <<FIN_SW
'use strict';
// Generado por netlify/build.sh — no editar a mano.
const VERSION = '${version}';
FIN_SW
  cat >> "$destino" <<'FIN_SW'
const CACHE = `remesa-${VERSION}`;
const SHELL = './';                       // el documento raíz de la SPA

// Nunca se tocan: son la API y las funciones de Netlify. Guardar en caché una
// respuesta con datos de una sesión sería un fallo de seguridad, no una mejora.
const NUNCA = /^\/(api|health|\.netlify)\b/;

self.addEventListener('install', (evento) => {
  self.skipWaiting();                     // el build nuevo manda desde ya
  evento.waitUntil(
    caches.open(CACHE).then((c) => c.add(new Request(SHELL, { cache: 'reload' })))
      .catch(() => {})                    // sin red en la instalación: da igual
  );
});

self.addEventListener('activate', (evento) => {
  evento.waitUntil((async () => {
    const nombres = await caches.keys();
    await Promise.all(nombres.filter((n) => n !== CACHE).map((n) => caches.delete(n)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (evento) => {
  const peticion = evento.request;
  if (peticion.method !== 'GET') return;

  const url = new URL(peticion.url);
  if (url.origin !== self.location.origin) return;   // fuentes, terceros…
  if (NUNCA.test(url.pathname)) return;              // API y funciones

  // Navegaciones: primero la red, para no servir jamás una versión vieja de
  // la aplicación. Si no hay red, se devuelve el documento guardado.
  if (peticion.mode === 'navigate') {
    evento.respondWith((async () => {
      try {
        const respuesta = await fetch(peticion);
        const copia = respuesta.clone();
        caches.open(CACHE).then((c) => c.put(SHELL, copia)).catch(() => {});
        return respuesta;
      } catch (e) {
        const guardado = await caches.match(SHELL);
        if (guardado) return guardado;
        throw e;
      }
    })());
    return;
  }

  // Recursos (motor, fuentes de la app, iconos): se responde con lo guardado
  // si existe y se refresca en segundo plano.
  evento.respondWith((async () => {
    const guardado = await caches.match(peticion);
    const red = fetch(peticion).then((respuesta) => {
      if (respuesta && respuesta.ok && respuesta.type === 'basic') {
        const copia = respuesta.clone();
        caches.open(CACHE).then((c) => c.put(peticion, copia)).catch(() => {});
      }
      return respuesta;
    }).catch(() => guardado);
    return guardado || red;
  })());
});
FIN_SW

  node --check "$destino" && echo "  ▸ service worker válido ($(wc -c < "$destino") B)"
}

# ═════════════════════════════════════════════════════════════
#  Catálogo de proyectos y recorrido de capturas
#
#  Se publican dentro del mismo sitio (/catalogo y /capturas) en lugar de
#  crear un segundo proyecto en Netlify. El catálogo se regenera desde
#  catalogo/proyectos.json, así que para actualizarlo basta con editar ese
#  JSON. Su único <script> en línea se extrae a un archivo aparte: la CSP
#  del sitio no permite scripts en línea y así no hay que relajarla.
# ═════════════════════════════════════════════════════════════
publicar_catalogo() {
  [ -f "$RAIZ/catalogo/proyectos.json" ] || return 0

  if [ -f "$RAIZ/herramientas/generar-catalogo.js" ]; then
    echo "▸ Regenerando el catálogo…"
    node "$RAIZ/herramientas/generar-catalogo.js" \
      || echo "  ⚠ No se pudo regenerar: se publica la copia del repositorio."
  fi

  [ -f "$RAIZ/catalogo/index.html" ] || return 0
  mkdir -p "$SALIDA/catalogo"

  local guion
  guion="$(mktemp /tmp/catalogo-XXXXXX.js)"
  cat > "$guion" <<'FIN_CATALOGO'
const fs = require('fs');
const path = require('path');
const [origen, destino] = process.argv.slice(2);

let html = fs.readFileSync(origen, 'utf8');
let n = 0;
html = html.replace(/<script(?![^>]*\ssrc=)[^>]*>([\s\S]*?)<\/script>/g, (_, codigo) => {
  fs.writeFileSync(path.join(destino, `catalogo-${++n}.js`), codigo);
  return `<script src="catalogo-${n}.js" defer></script>`;
});
fs.writeFileSync(path.join(destino, 'index.html'), html);
console.log(`  ▸ /catalogo publicado (${n} script(s) extraídos para cumplir la CSP)`);
FIN_CATALOGO
  node "$guion" "$RAIZ/catalogo/index.html" "$SALIDA/catalogo"
  rm -f "$guion"

  if [ -d "$RAIZ/capturas" ]; then
    mkdir -p "$SALIDA/capturas"
    cp -R "$RAIZ/capturas/." "$SALIDA/capturas/"
    echo "  ▸ /capturas publicado ($(ls -1 "$RAIZ/capturas" | wc -l) archivos)"
  fi
  [ -f "$RAIZ/GUIA_DE_PRUEBA.md" ] && cp "$RAIZ/GUIA_DE_PRUEBA.md" "$SALIDA/" || true
}

# ═════════════════════════════════════════════════════════════
#  Build
# ═════════════════════════════════════════════════════════════
echo "▸ Instalando dependencias del API…"
npm install --prefix "$RAIZ" --no-audit --no-fund

# Esquema de la base de datos: se aplica en el despliegue, no en cada
# invocación de la función. Es idempotente, así que repetirlo no molesta.
# Si falla no se tumba el build: el sitio estático debe publicarse igual y
# /health dirá exactamente qué pasa con la base de datos.
if [ -n "${DATABASE_URL:-}" ]; then
  echo "▸ Aplicando migraciones en Supabase…"
  npm run migrate --prefix "$RAIZ" || echo "  ⚠ Migración fallida: revisa DATABASE_URL (pooler :6543) y vuelve a desplegar."
else
  echo "  ⚠ Sin DATABASE_URL: me salto las migraciones. Añádela en las variables de entorno."
fi

if [ -f "$SALIDA/index.html" ] && [ "${FORCE_FLUTTER_BUILD:-0}" != "1" ]; then
  echo "✔ Build web ya presente en el repositorio: se publica tal cual."
  echo "  (exporta FORCE_FLUTTER_BUILD=1 para recompilar desde el fuente)"
  marca_pwa
  service_worker
  publicar_catalogo
  exit 0
fi

echo "▸ No hay build web. Preparando Flutter $VERSION_FLUTTER…"
export PUB_CACHE="$CACHE/pub"
SDK="$CACHE/flutter"

if [ ! -x "$SDK/bin/flutter" ]; then
  mkdir -p "$CACHE"
  URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${VERSION_FLUTTER}-stable.tar.xz"
  echo "  descargando $URL"
  curl -fsSL "$URL" -o /tmp/flutter.tar.xz
  tar -xJf /tmp/flutter.tar.xz -C "$CACHE"
  rm -f /tmp/flutter.tar.xz
fi

export PATH="$SDK/bin:$PATH"
git config --global --add safe.directory "$SDK" || true
flutter --version

cd "$RAIZ/mobile"
flutter pub get
# --no-wasm-dry-run: el canal estable falla la comprobación wasm con
# dependencias que usan dart:html (image_picker / flutter_secure_storage).
# --no-web-resources-cdn: CanvasKit se sirve desde /canvaskit (mismo origen).
# Sin esta opción lo pide a www.gstatic.com y la CSP lo bloquea: pantalla en blanco.
flutter build web --release --no-wasm-dry-run --no-web-resources-cdn

# Red de seguridad: si la opción anterior no dejara marcado el uso del
# CanvasKit local, se fuerza aquí. Sin esto el motor se pide a gstatic.com,
# la CSP lo bloquea y la aplicación queda en blanco en todos los dispositivos.
BOOT="$SALIDA/flutter_bootstrap.js"
if [ -f "$BOOT" ] && ! grep -q '"useLocalCanvasKit":true' "$BOOT"; then
  sed -i 's/_flutter\.buildConfig = {/_flutter.buildConfig = {"useLocalCanvasKit":true,/' "$BOOT"
  echo "  ▸ CanvasKit forzado a local en flutter_bootstrap.js"
fi

marca_pwa
service_worker
publicar_catalogo

echo "✔ Build web generado en $SALIDA"
