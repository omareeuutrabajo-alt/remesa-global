# Despliegue · Supabase + Netlify

Guía completa para poner **Remesa Global** en línea con tus propias cuentas.
Tiempo estimado: **15–20 minutos**. No hace falta tarjeta: todo cabe en los
planes gratuitos.

```
┌──────────────────────── Netlify ────────────────────────┐
│  CDN estático            Función Node (serverless)      │
│  Flutter Web             netlify/functions/api.js       │
│  mobile/build/web   ──▶  = misma app Express de siempre │
└───────────┬──────────────────────┬──────────────────────┘
            │  mismo origen        │ DATABASE_URL (pooler :6543)
            │  /api/v1/* ─────────▶│ SUPABASE_SERVICE_ROLE_KEY
            ▼                      ▼
     el cliente nunca      ┌──── Supabase ────┐
     cruza dominios        │ Postgres  (datos)│
     (sin CORS, sin        │ Storage   (KYC)  │
      preflight)           └──────────────────┘
```

**Por qué esta arquitectura** (y no otras que se evaluaron):

| Decisión | Alternativa descartada | Motivo |
|---|---|---|
| API Express en una función de Netlify | Supabase Edge Functions (Deno) | Reutiliza el 100 % del backend ya probado; cero reescritura. |
| Auth propia con JWT | Supabase Auth | El módulo es el producto: OTP, PIN, biometría, KYC y auditoría son reglas de negocio, no login genérico. |
| Acceso a Postgres por `pg` | PostgREST / `supabase-js` | Las 36 consultas existentes siguen valiendo; el SQL queda bajo control. |
| Front y API en el **mismo** origen | API en otro dominio | `AppConfig.apiBaseUrl` usa `${Uri.base.origin}/api/v1`: sin CORS ni cookies entre dominios. |

---

## 1 · Supabase — base de datos y almacenamiento

### 1.1 Crear el proyecto
1. [app.supabase.com](https://app.supabase.com) ▸ **New project**.
2. Nombre `remesa-global`, región la más cercana a tus usuarios, y **guarda la
   contraseña de la base de datos** (sólo se muestra una vez).

### 1.2 Aplicar el esquema
**Opción A — SQL Editor (la más rápida).** Copia el contenido de
`supabase/migrations/20260101000000_init.sql` en *SQL Editor ▸ New query* y
ejecútalo. Crea las 6 tablas, los índices, activa RLS y revoca el acceso
anónimo.

**Opción B — desde tu máquina.**
```bash
export DATABASE_URL="postgresql://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:6543/postgres"
npm run migrate
```

**Opción C — no hacer nada.** Si configuras `DATABASE_URL` en Netlify (paso
2.2), el script de build aplica las migraciones en cada despliegue. Son
idempotentes: repetirlas no rompe nada.

Comprueba en *Table Editor* que aparecen `users`, `otp_codes`,
`refresh_tokens`, `devices`, `kyc_submissions` y `audit_logs`.

> **Sobre la seguridad de las tablas.** La migración activa RLS **sin
> políticas** y hace `REVOKE ALL … FROM anon, authenticated`. Traducción: con
> la clave pública de Supabase nadie puede leer un solo hash de contraseña,
> aunque descubra la URL del proyecto. La API entra por conexión directa como
> dueña de las tablas, así que no se ve afectada.

### 1.3 Bucket privado para el KYC
*Storage ▸ New bucket* → nombre **`kyc`**, **Public: NO**.
(Si lo olvidas, el servidor lo crea solo en el primer envío.)

Los documentos nunca se sirven en abierto: el back-office pide una URL firmada
de 5 minutos (`kycService.signedFiles`).

### 1.4 Apuntar las tres credenciales
*Project Settings ▸ Database ▸ Connection string ▸ **Transaction pooler***
→ `DATABASE_URL` (**puerto 6543**, no el 5432: en serverless cada invocación
abre su propia conexión y el pooler es justo lo que evita agotar el cupo).

*Project Settings ▸ API* → `SUPABASE_URL` y **`service_role`** (`SUPABASE_SERVICE_ROLE_KEY`).

> La clave `service_role` salta todas las reglas de seguridad. Va **sólo** en
> las variables de Netlify. Nunca en el cliente Flutter ni en el repositorio.

---

## 2 · Netlify — sitio y función

### 2.1 Conectar el repositorio
*Add new site ▸ Import an existing project* → tu repositorio.
`netlify.toml` ya trae la configuración, así que los campos se rellenan solos:

| Campo | Valor |
|---|---|
| Build command | `bash netlify/build.sh` |
| Publish directory | `mobile/build/web` |
| Functions directory | `netlify/functions` |

### 2.2 Variables de entorno
*Site configuration ▸ Environment variables* ▸ **Add a variable**:

| Variable | Valor |
|---|---|
| `DATABASE_URL` | la cadena del pooler (puerto 6543) |
| `SUPABASE_URL` | `https://<ref>.supabase.co` |
| `SUPABASE_SERVICE_ROLE_KEY` | la clave `service_role` |
| `SUPABASE_KYC_BUCKET` | `kyc` |
| `JWT_ACCESS_SECRET` | genera uno nuevo ⬇ |
| `JWT_REFRESH_SECRET` | genera otro distinto ⬇ |
| `NODE_ENV` | `production` |
| `DEMO_MODE` | `true` (vitrina) · `false` (producción real) |
| `BCRYPT_ROUNDS` | `10` |

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
```

> **`DEMO_MODE=true`** mantiene visible el código OTP en la respuesta
> (`devCode`) y aprueba el KYC automáticamente a los 10 s. Sin esto la
> demostración sería imposible de recorrer: no hay pasarela de SMS ni
> verificador documental contratados. Los secretos JWT **no** se relajan nunca:
> el arranque aborta si detecta los de desarrollo con `NODE_ENV=production`.

> **`BCRYPT_ROUNDS=10`** en vez de 12: en una función fría, 12 rondas añaden
> cerca de un segundo al login. Con 10 el coste de romper un hash sigue siendo
> prohibitivo y la sesión se siente instantánea.

### 2.3 El build
`netlify/build.sh` publica `mobile/build/web`. Dos caminos:

- **Ya viene compilado en el repositorio** → se publica tal cual (~1 min).
  Para ello, en tu máquina: `cd mobile && flutter build web --release --no-wasm-dry-run`,
  y quita `mobile/build/` del `.gitignore` antes de subirlo.
- **No viene compilado** → el script descarga el SDK de Flutter (cacheado
  entre despliegues) y compila. El primer build tarda 5–8 min; los siguientes,
  2–3.

Fuerza siempre la compilación desde el fuente con `FORCE_FLUTTER_BUILD=1`.

---

## 3 · Comprobar que está vivo

```bash
SITIO=https://tu-sitio.netlify.app

# 1) Salud: base de datos y almacenamiento
curl -s $SITIO/health | jq
# → {"success":true,"data":{"status":"ok",
#    "database":{"estado":"ok","host":"…pooler.supabase.com:6543/postgres"},
#    "storage":"supabase", …}}

# 2) La batería completa contra el sitio desplegado (52 pruebas)
API_URL=$SITIO/api/v1 npm run test:e2e
```

Y a mano: abre el sitio, regístrate, copia el código que aparece en pantalla,
crea el PIN, sube dos fotos cualesquiera como documento y espera 10 segundos.

---

## 4 · El catálogo de proyectos (segundo sitio)

`catalogo/index.html` es una página autocontenida —estilos incrustados,
imágenes en data URI, cero dependencias— que se genera desde un único JSON:

```bash
node herramientas/generar-catalogo.js   # proyectos.json ▸ index.html
```

**Publicarla en Netlify** (sitio aparte, mismo repositorio):

1. *Add new site ▸ Import an existing project* → el mismo repositorio.
2. **Base directory**: vacío · **Build command**: `node herramientas/generar-catalogo.js`
   · **Publish directory**: `catalogo`
3. Listo: cada `git push` regenera el catálogo.

**Añadir un proyecto**: copia el bloque `plantilla` de `catalogo/proyectos.json`
dentro del array `proyectos`, rellénalo y vuelve a generar. Los campos:

| Campo | Para qué |
|---|---|
| `estado` | `en-vivo`, `en-curso` o `archivado` (define la etiqueta de color) |
| `destacado` | realza la ficha con un halo |
| `portada` / `icono` | rutas dentro de `catalogo/portadas/`, se incrustan solas |
| `metricas` | las cifras grandes: pruebas, pantallas, usuarios… |
| `caracteristicas` | lo que el proyecto sabe hacer, en frases cortas |
| `porQue` | la decisión de diseño que lo hace interesante |
| `stack` | alimenta además los filtros de la cabecera |
| `notas` | lo que **no** hace: limitaciones declaradas de frente |

Los filtros por tecnología se construyen solos a partir de los `stack`.

---

## 5 · Qué falta para que esto sea un producto real

Esto es una demostración técnica honesta. Antes de mover dinero de verdad:

| Pieza | Hoy | Para producción |
|---|---|---|
| SMS / correo | se escriben en el log | Twilio Verify, Resend, SNS… |
| Verificación documental | se aprueba sola a los 10 s | Jumio, Onfido, Sumsub (webhook → `kycService.review`) |
| Rate limiting | en memoria, por instancia | store compartido (Upstash Redis) |
| Secretos | variables de entorno | gestor de secretos + rotación |
| Trazabilidad | tabla `audit_logs` | export a SIEM y retención legal |
| Cumplimiento | — | licencia de remesador, AML/PEP, reporte de operaciones |

---

## 6 · Problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| `/health` → `database.estado: error` | `DATABASE_URL` mal copiada o puerto 5432 | usa la cadena del **Transaction pooler** (6543) |
| `prepared statement … already exists` | pgbouncer en modo transacción | ya resuelto: el driver nunca usa sentencias con nombre |
| Login lento (3–5 s) | arranque en frío + bcrypt 12 | `BCRYPT_ROUNDS=10`; la función se mantiene caliente con tráfico |
| El OTP no aparece | `DEMO_MODE` ausente | ponla a `true` y vuelve a desplegar |
| La subida del KYC falla con 413 | fichero > 6 MB | Netlify corta ahí; baja `MAX_UPLOAD_MB` o comprime en el cliente |
| Rutas 404 al recargar (`/login`) | falta el fallback SPA | ya está en `netlify.toml`; revisa que el deploy lo haya leído |
| `Function not found` | carpeta de funciones mal configurada | `functions = "netlify/functions"` en `netlify.toml` |
