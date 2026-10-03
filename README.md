# Remesa Global · Módulo de inicio

Módulo de autenticación y onboarding de nivel producción para una aplicación de
remesas: **Flutter** (iOS · Android · Web) + **API Node/Express** con JWT, OTP,
PIN, biometría y verificación de identidad (KYC).

```
remesas-app/
├── backend/     API REST · Node 20 · Express · PostgreSQL · JWT
├── mobile/      App Flutter 3.47 · Riverpod · go_router · Dio
├── supabase/    migraciones SQL (fuente única del esquema)
├── netlify/     función serverless + script de build
├── catalogo/    vitrina de proyectos (HTML autocontenido)
├── capturas/    24 pantallas + galería
└── herramientas/ automatización (capturas, catálogo)
```

**En línea:** el mismo código corre en local y desplegado — el front estático
en el CDN de Netlify y la API dentro de una función Node, con Postgres y
Storage de Supabase detrás. Instrucciones completas en **[DEPLOY.md](DEPLOY.md)**.

---

## 1. Qué incluye el módulo

| Flujo | Pantallas | Respaldo en la API |
|---|---|---|
| Arranque | Splash con restauración de sesión | `GET /auth/me` |
| Bienvenida | Onboarding de 3 pasos (una sola vez) | — |
| Registro | Formulario con medidor de fortaleza y selector de país | `POST /auth/register` |
| Verificación 2FA | Código de 6 dígitos, reenvío con cuenta atrás | `POST /auth/otp/verify` · `/otp/resend` |
| Inicio de sesión | Correo + contraseña, bloqueo por intentos | `POST /auth/login` |
| Recuperación | Correo → OTP → nueva contraseña | `/password/forgot` · `/password/reset` |
| PIN | Creación (crear + confirmar) y desbloqueo | `POST /auth/pin` · `/pin/verify` |
| Biometría | Alta opcional y acceso rápido | `/biometric/enroll` · `/biometric/login` |
| KYC | Documento (frente/reverso) + selfie + seguimiento | `POST /kyc/submit` · `GET /kyc/status` |
| Home | Estado de cuenta, límites y panel de seguridad | `GET /auth/sessions` |

La navegación **no la deciden los botones**: el backend devuelve un `nextStep`
(`verify_otp` → `pin_setup` → `kyc` → `home`) y el router de la app aplica esa
decisión. Es imposible saltarse un paso del onboarding manipulando el cliente.

---

## 2. Puesta en marcha

### API

```bash
cd backend
npm install
cp .env.example .env        # ajusta los secretos

# Postgres local (o apunta DATABASE_URL a tu Supabase y sáltate este paso)
npm run db:local            # initdb + createdb en /var/tmp/pgdata
#   con Docker:  docker run -d -e POSTGRES_PASSWORD=postgres \
#                  -e POSTGRES_DB=remesas -p 5432:5432 postgres:16

npm run migrate             # aplica supabase/migrations/*.sql
npm start                   # http://localhost:4000
npm run test:e2e            # 52 pruebas de extremo a extremo
```

### App Flutter

```bash
cd mobile
flutter pub get
flutter run                 # emulador Android / simulador iOS
flutter test                # 19 pruebas unitarias
flutter analyze             # sin incidencias
```

La URL de la API se resuelve sola (`lib/core/config/app_config.dart`):

| Plataforma | URL |
|---|---|
| Emulador Android | `http://10.0.2.2:4000/api/v1` |
| Simulador iOS / escritorio | `http://localhost:4000/api/v1` |
| Web | mismo origen que el servidor |

Para apuntar a otro entorno:
`flutter run --dart-define=API_URL=https://api.tudominio.com/api/v1`

### Demostración web

El backend sirve automáticamente el build web si existe:

```bash
cd mobile && flutter build web --release
cd ../backend && npm start      # la app queda en http://localhost:4000
```

> En modo desarrollo el código SMS **se muestra en la propia pantalla** (campo
> `devCode`), para poder recorrer el flujo completo sin pasarela de SMS real.
> En producción `EXPOSE_OTP_IN_RESPONSE` se ignora por completo.

---

## 3. Seguridad implementada

**Credenciales**
- Contraseñas con bcrypt (coste 12) y política de fortaleza compartida entre
  cliente y servidor (misma fórmula 0-4, sin sorpresas al enviar el formulario).
- PIN de 6 dígitos hasheado, con lista de PIN prohibidos (`123456`, repetidos…).
- Bloqueo temporal de la cuenta tras 5 intentos fallidos (login o PIN).

**Sesiones**
- Access token JWT de 15 minutos + refresh token opaco de 30 días.
- El refresh se guarda **hasheado** (SHA-256): una fuga de base de datos no
  permite suplantar sesiones.
- **Rotación con detección de reuso**: si un refresh ya revocado se vuelve a
  presentar, se asume robo y se revocan todas las sesiones del usuario.
- Renovación transparente en el cliente, con cola para que N peticiones
  concurrentes disparen un solo refresh.

**Segundo factor**
- OTP de 6 dígitos generado con CSPRNG sin sesgo de módulo, guardado hasheado,
  con caducidad de 5 minutos, máximo 5 intentos y enfriamiento de reenvío.
- Dispositivos de confianza: el OTP solo se pide en dispositivos nuevos.
- Biometría anclada al dispositivo mediante un token opaco revocable; la huella
  o el rostro nunca salen del teléfono.

**Superficie de ataque**
- Rate limiting por IP y por tipo de operación (registro, login, OTP).
- Respuestas anti-enumeración: mismo mensaje exista o no el correo.
- Comparaciones en tiempo constante, cabeceras con Helmet, validación estricta
  con Zod en todas las entradas.
- Bitácora de auditoría de cada evento sensible (`audit_logs`) para compliance.
- Enmascarado de PII en respuestas y registros (`j****z@mail.com`, `+58 *** *** 4567`).

**Cliente**
- Tokens en Keychain (iOS) / Keystore (Android) vía `flutter_secure_storage`;
  nunca en `SharedPreferences`.
- Bloqueo automático con PIN tras 3 minutos de inactividad.
- Teclado numérico propio para el PIN (no alimenta el diccionario predictivo).

---

## 4. Arquitectura

### Backend — por capas

```
src/
├── config/        entorno validado y pool de Postgres
├── db/            lanzador de migraciones (el SQL vive en supabase/migrations)
├── middleware/    auth, validación Zod, rate limit, subidas, errores
├── services/      reglas de negocio (auth, otp, tokens, dispositivos, kyc, almacenamiento)
├── controllers/   adaptan HTTP ↔ servicios
├── routes/        declaración de endpoints
└── utils/         jwt, bcrypt, cripto, enmascarado, logger
```

Los controladores no tocan la base de datos y los servicios no conocen Express:
se puede exponer la misma lógica por gRPC o por una cola sin reescribir nada.
Esa separación es la que permitió pasar de SQLite a Postgres y de servidor
propio a función serverless tocando **dos** ficheros: `config/database.js` y
`services/storageService.js`.

```
         local                         Netlify
  node src/server.js            netlify/functions/api.js
          └──────────┬────────────────────┘
                     ▼
              createApp()  ← la misma app de Express
                     ▼
     pg.Pool ──▶ Postgres        storageService ──▶ disco | Supabase Storage
```

### App — por funcionalidad (feature-first)

```
lib/
├── core/
│   ├── config/    entornos y constantes
│   ├── theme/     paleta, tipografía, componentes Material 3
│   ├── network/   Dio + interceptores + errores de dominio
│   ├── storage/   almacén cifrado y preferencias
│   ├── router/    go_router con guardas por estado de sesión
│   ├── utils/     validadores, países, identidad del dispositivo
│   └── widgets/   botones, campos, OTP, teclado PIN, avisos
└── features/
    ├── auth/      data (modelos + repositorio) · application (Riverpod) · presentation
    ├── kyc/       repositorio y flujo de 3 pasos
    └── home/      pantalla posterior al onboarding
```

Las pantallas no contienen lógica de negocio: observan `AuthState` y llaman
métodos de `AuthController`. Eso hace el módulo testeable y portable.

---

## 5. Endpoints

Base: `/api/v1` · Respuesta uniforme `{ success, data }` o `{ success, error:{ code, message, details } }`.

### Autenticación

| Método | Ruta | Descripción |
|---|---|---|
| `POST` | `/auth/register` | Alta de usuario y envío de OTP |
| `POST` | `/auth/login` | Inicio de sesión (puede exigir OTP) |
| `POST` | `/auth/otp/verify` | Verifica el código de los 3 flujos |
| `POST` | `/auth/otp/resend` | Reenvía el código con enfriamiento |
| `POST` | `/auth/password/forgot` | Inicia la recuperación |
| `POST` | `/auth/password/reset` | Fija la nueva contraseña |
| `POST` | `/auth/refresh` | Rota el par de tokens |
| `POST` | `/auth/biometric/login` | Entrada con token biométrico |

### Requieren `Authorization: Bearer <access>`

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/auth/me` | Perfil y siguiente paso del onboarding |
| `GET` | `/auth/sessions` | Sesiones activas y actividad reciente |
| `POST` | `/auth/pin` · `/auth/pin/verify` | Configura y valida el PIN |
| `POST` | `/auth/password/change` | Cambia la contraseña |
| `POST` | `/auth/biometric/enroll` · `/disable` | Gestiona la biometría |
| `POST` | `/auth/logout` | Cierra la sesión (o todas) |
| `POST` | `/kyc/submit` | Envía documento y selfie (multipart) |
| `GET` | `/kyc/status` · `/kyc/limits` | Estado y límites por nivel |

Códigos de error estables para internacionalizar en el cliente:
`INVALID_CREDENTIALS`, `ACCOUNT_LOCKED`, `OTP_EXPIRED`, `OTP_INVALID`,
`OTP_MAX_ATTEMPTS`, `PIN_WEAK`, `REFRESH_REUSED`, `KYC_REQUIRED`…

### Límites por nivel KYC

| Nivel | Estado | Por transacción | Diario | Mensual |
|---|---|---|---|---|
| 0 | Sin verificar | $0 | $0 | $0 |
| 1 | Verificado | $1 000 | $2 000 | $10 000 |
| 2 | Verificado plus | $5 000 | $10 000 | $50 000 |

---

## 6. Pruebas

```bash
cd backend && npm run test:e2e         # 52 ✓  flujo completo + casos de ataque
cd backend && npm run test:serverless  # 13 ✓  la función de Netlify, sin red
cd backend && npm run test:storage     # 11 ✓  Supabase Storage emulado
cd mobile  && flutter test             # 19 ✓  validadores, modelos y estado
cd mobile  && flutter analyze          #  0 incidencias
```

La suite E2E recorre registro → OTP → PIN → KYC → rotación de tokens →
biometría → recuperación → cierre de sesión, e incluye verificaciones negativas
(reuso de OTP, token robado, enumeración de correos, PIN débiles).

Las otras dos cubren lo que sólo existe en producción, que es justo donde no se
puede depurar cómodamente:

- **`serverless`** invoca el handler con eventos de Netlify reales: rutas con el
  prefijo `/.netlify/functions/api`, cuerpos multipart en base64 y peticiones
  sin socket (donde `req.ip` es `undefined` y el rate limit metería a todo el
  mundo en el mismo cubo).
- **`storage`** levanta un emulador de la API de Supabase Storage y verifica que
  el bucket se crea privado, que las URLs caducan y que el borrado por usuario
  no deja restos.

### Recorrido visual automatizado

`herramientas/capturar.js` abre la app en un Chromium real, completa el alta de
una usuaria de principio a fin (incluidas las fotos del KYC) y deja 24 capturas
en `capturas/`, más una galería navegable:

```bash
cd backend && npm start                  # sirve API + build web en :4000
cd ../herramientas && node capturar.js   # 24 capturas en ~85 s
open ../capturas/galeria.html            # galería · también capturas/mosaico.png
```

Playwright no puede hacer clic sobre un canvas de CanvasKit, así que la app se
pilota por el **árbol de semántica**; por eso la build de demostración se
compila con `--dart-define=ENABLE_SEMANTICS=true`.

Cuatro fallos reales salieron de este recorrido y ya están corregidos:

| Síntoma | Causa | Arreglo |
|---|---|---|
| El KYC no enviaba nada al pulsar *Enviar verificación* | la CSP bloqueaba `fetch` sobre las `blob:` URL de `image_picker` | `connect-src` admite `blob:` |
| La selfie no abría nada en navegador | `ImageSource.camera` no existe en web | en web se usa el selector de ficheros |
| Primer fotograma encogido a ~52 % del ancho | el `Container` del splash se ajustaba a su hijo con restricciones sueltas | `BoxConstraints.expand()` |
| La app arrancaba sin `<meta name="viewport">` | plantilla por defecto de Flutter | etiqueta añadida en `web/index.html` |

El splash, además, tiene ahora un mínimo de marca de 1,1 s
(`AuthController.duracionMinimaSplash`) que corre en paralelo a la restauración
de sesión: nunca añade espera si la API tarda más.

---

## 7. Pasos para llevarlo a producción

1. **Secretos**: generar `JWT_ACCESS_SECRET` y `JWT_REFRESH_SECRET`
   (`openssl rand -hex 48`) y moverlos a un gestor de secretos.
2. **Base de datos**: ✅ ya es PostgreSQL (Supabase). Queda activar copias de
   seguridad con retención y una réplica de lectura si el tráfico lo pide.
3. **Notificaciones**: sustituir el cuerpo de `services/notificationService.js`
   por Twilio/SendGrid; la interfaz ya está aislada.
4. **KYC real**: conectar `services/kycService.review()` al webhook de Jumio,
   Onfido o Truora y mover los archivos a S3 con cifrado en reposo.
5. **Almacenamiento de documentos**: ✅ bucket privado de Supabase con URLs
   firmadas de 5 minutos. Falta la política de retención y el cifrado con
   clave propia.
6. **Observabilidad**: exportar `audit_logs` a un SIEM y añadir alertas sobre
   `auth.refresh_reuse_detected` y `auth.login_failed`.
7. **Rate limiting**: hoy es en memoria y en serverless cada instancia lleva su
   propia cuenta; con tráfico real, un store compartido (Upstash Redis).
8. **App**: certificado pinning, `FLAG_SECURE` en pantallas con datos sensibles
   y revisión de ofuscación (`flutter build apk --obfuscate --split-debug-info`).
