#!/usr/bin/env node
'use strict';
/**
 * Genera catalogo/index.html a partir de catalogo/proyectos.json.
 *
 * El HTML sale autocontenido: las imágenes se incrustan como data URI y no
 * hay hojas de estilo ni scripts externos. Así el catálogo funciona abierto
 * con doble clic desde el disco, dentro de una vista previa aislada y
 * publicado en Netlify, sin depender de nada.
 *
 *   node herramientas/generar-catalogo.js
 */
const fs = require('node:fs');
const path = require('node:path');

const RAIZ = path.resolve(__dirname, '..');
const DIR = path.join(RAIZ, 'catalogo');
const datos = JSON.parse(fs.readFileSync(path.join(DIR, 'proyectos.json'), 'utf8'));

// ───────────────────────── utilidades ─────────────────────────
const esc = (s = '') => String(s)
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;').replace(/'/g, '&#39;');

/** Convierte una imagen local en data URI; si no existe, devuelve null. */
function incrustar(rel) {
  if (!rel) return null;
  const abs = path.join(DIR, rel);
  if (!fs.existsSync(abs)) {
    console.warn(`  ⚠ imagen no encontrada: ${rel}`);
    return null;
  }
  const tipo = { '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png', '.webp': 'image/webp' }[
    path.extname(abs).toLowerCase()
  ] || 'image/jpeg';
  return `data:${tipo};base64,${fs.readFileSync(abs).toString('base64')}`;
}

const ESTADOS = {
  'en-vivo': { texto: 'En vivo', clase: 'vivo' },
  'en-curso': { texto: 'En curso', clase: 'curso' },
  archivado: { texto: 'Archivado', clase: 'archivado' },
};

// ───────────────────────── plantillas ─────────────────────────
function ficha(p, i) {
  const estado = ESTADOS[p.estado] || ESTADOS['en-curso'];
  const portada = incrustar(p.portada);
  const icono = incrustar(p.icono);

  const enlaces = (p.enlaces || []).map((e) => `
          <a class="enlace ${e.tipo === 'primario' ? 'primario' : ''}" href="${esc(e.url)}"${
    /^https?:/.test(e.url) ? ' target="_blank" rel="noopener"' : ''
  }>${esc(e.etiqueta)}${e.tipo === 'primario' ? ' <span aria-hidden="true">→</span>' : ''}</a>`).join('');

  return `
      <article class="ficha${p.destacado ? ' destacada' : ''}" data-estado="${esc(p.estado)}" data-stack="${esc((p.stack || []).join('|').toLowerCase())}" style="--retardo:${i * 90}ms">
        ${portada ? `<div class="portada"><img src="${portada}" alt="Pantallas de ${esc(p.nombre)}" loading="lazy"></div>` : ''}
        <div class="cuerpo">
          <header class="cabecera">
            ${icono ? `<img class="icono" src="${icono}" alt="">` : ''}
            <div class="titulo">
              <h3>${esc(p.nombre)}</h3>
              <p class="lema">${esc(p.lema)}</p>
            </div>
            <span class="estado ${estado.clase}"><i></i>${estado.texto}</span>
          </header>

          <p class="descripcion">${esc(p.descripcion)}</p>

          ${p.metricas?.length ? `<dl class="metricas">${p.metricas.map((m) => `
            <div><dt>${esc(m.valor)}</dt><dd>${esc(m.etiqueta)}</dd></div>`).join('')}
          </dl>` : ''}

          ${p.caracteristicas?.length ? `<ul class="caracteristicas">${p.caracteristicas.map((c) => `
            <li>${esc(c)}</li>`).join('')}
          </ul>` : ''}

          ${p.porQue ? `<blockquote class="porque"><span>Por qué</span>${esc(p.porQue)}</blockquote>` : ''}

          <ul class="stack">${(p.stack || []).map((t) => `<li>${esc(t)}</li>`).join('')}</ul>

          ${p.notas ? `<p class="notas"><strong>Honestidad primero:</strong> ${esc(p.notas)}</p>` : ''}

          <nav class="enlaces">${enlaces}</nav>
        </div>
      </article>`;
}

function pagina(d) {
  const proyectos = d.proyectos || [];
  const tecnologias = [...new Set(proyectos.flatMap((p) => p.stack || []))].sort((a, b) => a.localeCompare(b, 'es'));
  const enVivo = proyectos.filter((p) => p.estado === 'en-vivo').length;

  return `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(d.titular.nombre)}</title>
<meta name="description" content="${esc(d.titular.lema)}">
<meta name="color-scheme" content="dark light">
<style>
  :root{
    --azul:#1757D6; --celeste:#17B3E8; --marino:#0A1734; --verde:#0FA968;
    --ambar:#F59E0B; --rojo:#E0394B; --lienzo:#F6F8FC;
    --fondo:#070E20; --panel:#0E1A33; --panel2:#132B4F; --borde:#1E2E4F;
    --texto:#E9EFFA; --tenue:#93A4C4;
    --r-s:10px; --r-m:14px; --r-l:20px; --r-xl:28px;
    font-synthesis-weight:none;
  }
  *{box-sizing:border-box;margin:0;padding:0}
  body{
    background:var(--fondo); color:var(--texto);
    font:16px/1.65 ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif;
    -webkit-font-smoothing:antialiased; padding:0 20px 80px;
    background-image:
      radial-gradient(900px 500px at 12% -8%, rgba(23,87,214,.30), transparent 62%),
      radial-gradient(760px 440px at 92% 4%, rgba(23,179,232,.18), transparent 60%);
    background-attachment:fixed;
  }
  .contenedor{max-width:1080px;margin:0 auto}

  /* ───── cabecera ───── */
  header.principal{padding:72px 0 44px;max-width:760px}
  .marca{display:inline-flex;align-items:center;gap:10px;font-weight:600;font-size:13px;
    letter-spacing:.14em;text-transform:uppercase;color:var(--celeste);margin-bottom:22px}
  .marca i{width:9px;height:9px;border-radius:50%;background:var(--verde);
    box-shadow:0 0 0 4px rgba(15,169,104,.18);animation:latido 2.6s ease-in-out infinite}
  @keyframes latido{50%{box-shadow:0 0 0 9px rgba(15,169,104,0)}}
  h1{font-size:clamp(34px,5.4vw,56px);line-height:1.08;letter-spacing:-.025em;font-weight:700}
  h1 em{font-style:normal;background:linear-gradient(100deg,var(--celeste),var(--azul));
    -webkit-background-clip:text;background-clip:text;color:transparent}
  header.principal p{margin-top:18px;font-size:18px;color:var(--tenue);max-width:62ch}
  .contacto{display:flex;flex-wrap:wrap;gap:10px;margin-top:28px}
  .contacto a{display:inline-flex;align-items:center;gap:7px;padding:8px 15px;border-radius:999px;
    border:1px solid var(--borde);background:rgba(255,255,255,.03);color:var(--texto);
    text-decoration:none;font-size:14px;transition:.18s}
  .contacto a:hover{border-color:var(--celeste);background:rgba(23,179,232,.10);transform:translateY(-1px)}
  .contacto span{color:var(--tenue)}

  /* ───── filtros ───── */
  .barra{display:flex;flex-wrap:wrap;gap:8px;align-items:center;
    padding:16px 0 28px;border-top:1px solid var(--borde);margin-top:44px}
  .barra .cuenta{margin-right:auto;font-size:14px;color:var(--tenue)}
  .barra .cuenta b{color:var(--texto);font-weight:600}
  .filtro{padding:7px 14px;border-radius:999px;border:1px solid var(--borde);
    background:transparent;color:var(--tenue);font:inherit;font-size:13.5px;cursor:pointer;transition:.18s}
  .filtro:hover{color:var(--texto);border-color:#2C4A86}
  .filtro[aria-pressed="true"]{background:var(--azul);border-color:var(--azul);color:#fff}

  /* ───── fichas ───── */
  .rejilla{display:grid;gap:26px}
  .ficha{border:1px solid var(--borde);border-radius:var(--r-xl);overflow:hidden;
    background:linear-gradient(180deg,rgba(19,33,61,.92),rgba(10,23,52,.92));
    animation:entrar .5s both;animation-delay:var(--retardo);transition:border-color .2s,transform .2s}
  @keyframes entrar{from{opacity:0;transform:translateY(14px)}}
  .ficha:hover{border-color:#2B4A86;transform:translateY(-2px)}
  .ficha.oculta{display:none}
  .ficha.destacada{box-shadow:0 24px 70px -34px rgba(23,87,214,.85)}
  .portada{background:var(--lienzo);padding:0;line-height:0;border-bottom:1px solid var(--borde)}
  .portada img{width:100%;height:auto;display:block}
  .cuerpo{padding:30px}
  @media(max-width:560px){.cuerpo{padding:22px}}

  .cabecera{display:flex;align-items:flex-start;gap:14px;margin-bottom:18px}
  .icono{width:46px;height:46px;border-radius:var(--r-m);object-fit:cover;flex:0 0 auto;
    border:1px solid var(--borde)}
  .titulo{flex:1 1 auto;min-width:0}
  .titulo h3{font-size:25px;letter-spacing:-.015em;line-height:1.2}
  .lema{color:var(--tenue);font-size:15px;margin-top:3px}
  .estado{display:inline-flex;align-items:center;gap:7px;flex:0 0 auto;
    padding:5px 12px;border-radius:999px;font-size:12.5px;font-weight:600;letter-spacing:.01em}
  .estado i{width:7px;height:7px;border-radius:50%;background:currentColor}
  .estado.vivo{color:#49E39B;background:rgba(15,169,104,.14);border:1px solid rgba(15,169,104,.32)}
  .estado.curso{color:#FFC46B;background:rgba(245,158,11,.14);border:1px solid rgba(245,158,11,.32)}
  .estado.archivado{color:var(--tenue);background:rgba(147,164,196,.12);border:1px solid var(--borde)}

  .descripcion{color:#C7D4EA;margin-bottom:22px}

  .metricas{display:grid;grid-template-columns:repeat(auto-fit,minmax(104px,1fr));gap:1px;
    background:var(--borde);border:1px solid var(--borde);border-radius:var(--r-m);
    overflow:hidden;margin-bottom:22px}
  .metricas>div{background:#0C182F;padding:15px 12px;text-align:center}
  .metricas dt{font-size:23px;font-weight:700;letter-spacing:-.02em;
    background:linear-gradient(100deg,var(--celeste),var(--azul));
    -webkit-background-clip:text;background-clip:text;color:transparent}
  .metricas dd{font-size:12px;color:var(--tenue);margin-top:2px;
    text-transform:uppercase;letter-spacing:.07em}

  .caracteristicas{list-style:none;display:grid;gap:9px;margin-bottom:22px}
  .caracteristicas li{position:relative;padding-left:26px;font-size:15px;color:#C7D4EA}
  .caracteristicas li::before{content:"";position:absolute;left:4px;top:.62em;
    width:7px;height:7px;border-radius:2px;background:var(--celeste);transform:rotate(45deg)}

  .porque{border-left:3px solid var(--azul);padding:4px 0 4px 16px;margin-bottom:22px;
    color:#B9C8E4;font-size:15px}
  .porque span{display:block;font-size:11.5px;letter-spacing:.14em;text-transform:uppercase;
    color:var(--celeste);font-weight:600;margin-bottom:4px}

  .stack{list-style:none;display:flex;flex-wrap:wrap;gap:7px;margin-bottom:22px}
  .stack li{font-size:12.5px;padding:4px 11px;border-radius:999px;
    border:1px solid var(--borde);color:var(--tenue);background:rgba(255,255,255,.02)}

  .notas{font-size:13.5px;color:var(--tenue);background:rgba(245,158,11,.07);
    border:1px solid rgba(245,158,11,.22);border-radius:var(--r-s);padding:12px 14px;margin-bottom:22px}
  .notas strong{color:var(--ambar)}

  .enlaces{display:flex;flex-wrap:wrap;gap:10px}
  .enlace{display:inline-flex;align-items:center;gap:7px;padding:10px 18px;border-radius:var(--r-s);
    text-decoration:none;font-size:14.5px;font-weight:500;transition:.18s;
    border:1px solid var(--borde);color:var(--texto);background:rgba(255,255,255,.03)}
  .enlace:hover{border-color:var(--celeste);background:rgba(23,179,232,.10)}
  .enlace.primario{background:var(--azul);border-color:var(--azul);color:#fff}
  .enlace.primario:hover{background:#1B64F0;border-color:#1B64F0;
    box-shadow:0 12px 30px -14px rgba(23,87,214,.95)}

  .vacio{text-align:center;color:var(--tenue);padding:60px 20px;display:none}
  .vacio.visible{display:block}

  footer{margin-top:60px;padding-top:26px;border-top:1px solid var(--borde);
    color:var(--tenue);font-size:13.5px;display:flex;flex-wrap:wrap;gap:12px;justify-content:space-between}
  code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.92em;
    background:rgba(255,255,255,.06);padding:1px 6px;border-radius:5px}
  @media(prefers-reduced-motion:reduce){*{animation:none!important;transition:none!important}}
</style>
</head>
<body>
<div class="contenedor">

  <header class="principal">
    <div class="marca"><i></i>${enVivo} proyecto${enVivo === 1 ? '' : 's'} en línea ahora mismo</div>
    <h1>${esc(d.titular.nombre).replace(/^(\S+)/, '<em>$1</em>')}</h1>
    <p>${esc(d.titular.lema)}</p>
    <p style="margin-top:12px;font-size:16px">${esc(d.titular.descripcion)}</p>
    <div class="contacto">
      ${(d.titular.contacto || []).map((c) => `<a href="${esc(c.url)}"${
        /^https?:/.test(c.url) ? ' target="_blank" rel="noopener"' : ''
      }><span>${esc(c.etiqueta)}</span> ${esc(c.valor)}</a>`).join('\n      ')}
    </div>
  </header>

  <div class="barra" role="toolbar" aria-label="Filtrar proyectos">
    <span class="cuenta"><b id="visibles">${proyectos.length}</b> de ${proyectos.length} proyectos</span>
    <button class="filtro" data-filtro="*" aria-pressed="true">Todos</button>
    ${tecnologias.map((t) => `<button class="filtro" data-filtro="${esc(t.toLowerCase())}" aria-pressed="false">${esc(t)}</button>`).join('\n    ')}
  </div>

  <main class="rejilla">
${proyectos.map(ficha).join('\n')}
  </main>

  <p class="vacio" id="vacio">No hay proyectos con esa tecnología.</p>

  <footer>
    <span>Generado desde <code>catalogo/proyectos.json</code> · ${new Date().toLocaleDateString('es', { day: 'numeric', month: 'long', year: 'numeric' })}</span>
    <span>Añade un proyecto: edita el JSON y ejecuta <code>node herramientas/generar-catalogo.js</code></span>
  </footer>
</div>

<script>
  // Filtro por tecnología. Sin dependencias: el catálogo debe seguir
  // funcionando aunque se abra desde el disco o sin conexión.
  var botones = document.querySelectorAll('.filtro');
  var fichas = document.querySelectorAll('.ficha');
  var contador = document.getElementById('visibles');
  var vacio = document.getElementById('vacio');

  botones.forEach(function (b) {
    b.addEventListener('click', function () {
      botones.forEach(function (o) { o.setAttribute('aria-pressed', String(o === b)); });
      var f = b.dataset.filtro, n = 0;
      fichas.forEach(function (ficha) {
        var coincide = f === '*' || ('|' + ficha.dataset.stack + '|').indexOf('|' + f + '|') !== -1;
        ficha.classList.toggle('oculta', !coincide);
        if (coincide) n++;
      });
      contador.textContent = n;
      vacio.classList.toggle('visible', n === 0);
    });
  });
</script>
</body>
</html>
`;
}

const html = pagina(datos);
const destino = path.join(DIR, 'index.html');
fs.writeFileSync(destino, html);
console.log(`✔ Catálogo generado: ${path.relative(RAIZ, destino)} (${Math.round(html.length / 1024)} KB, ${datos.proyectos.length} proyecto(s))`);
