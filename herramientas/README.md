# Herramientas de captura

Recorren la app **de verdad** en un Chromium headless y guardan una captura por
pantalla en `../capturas/`. Playwright pilota Flutter a través de su **árbol de
semántica** (el mismo que usa un lector de pantalla), porque CanvasKit pinta en
un canvas y no expone widgets al DOM.

```bash
# 1. backend + build web servidos en :4000
cd ../backend && npm start

# 2. navegador headless (una sola vez)
npm i playwright-core && npx playwright-core install chromium

# 3. recorrido completo (24 capturas, ~85 s)
node capturar.js

# 4. solo la pantalla de arranque
node capturar-splash.js
```

Requisitos de la build: compilar con `--dart-define=ENABLE_SEMANTICS=true`
para que `main.dart` llame a `SemanticsBinding.instance.ensureSemantics()`.

`muestras/` contiene el documento y la selfie sintéticos que se suben al KYC.
