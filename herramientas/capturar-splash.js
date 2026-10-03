// Regenera la captura del splash. CanvasKit solo entrega un fotograma nuevo
// cuando repinta, así que probamos varios instantes y nos quedamos con el bueno.
const { chromium } = require('playwright-core');
(async () => {
  const b = await chromium.launch({
    args: ['--no-sandbox', '--disable-dev-shm-usage', '--hide-scrollbars',
           '--window-size=400,860'],
  });
  for (const espera of [700, 800, 900, 1000, 1100, 1200]) {
    const ctx = await b.newContext({ viewport: null, locale: 'es-VE' });
    const p = await ctx.newPage();
    await p.goto(process.env.APP_URL || 'http://localhost:4000', { waitUntil: 'commit' });
    await p.waitForTimeout(espera);
    await p.screenshot({ path: `/var/tmp/splash-${espera}.png` });
    await ctx.close();
  }
  console.log('intentos listos');
  await b.close();
})();
