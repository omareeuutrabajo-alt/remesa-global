#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  Build de Netlify: deja listo mobile/build/web
#
#  1) Si el repositorio ya trae el build web compilado, se usa tal cual
#     (despliegue en ~1 minuto, sin depender del SDK).
#  2) Si no, se descarga el SDK de Flutter —cacheado entre despliegues—
#     y se compila desde el código fuente.
# ─────────────────────────────────────────────────────────────
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SALIDA="$RAIZ/mobile/build/web"
VERSION_FLUTTER="${FLUTTER_VERSION:-3.47.6}"
CACHE="${NETLIFY_BUILD_BASE:-/opt/build}/cache"

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
flutter build web --release --no-wasm-dry-run

echo "✔ Build web generado en $SALIDA"
