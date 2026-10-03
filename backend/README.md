# Remesas Auth API

API de autenticación, OTP, PIN, biometría y KYC. Node 20 · Express · PostgreSQL · JWT.

Corre igual como servidor tradicional (`node src/server.js`) que dentro de una
función de Netlify (`netlify/functions/api.js`): es la misma app de Express.

## Arranque

```bash
npm install
cp .env.example .env

npm run db:local      # Postgres local en /var/tmp/pgdata (o usa Docker/Supabase)
npm run migrate       # aplica supabase/migrations/*.sql

npm start             # http://localhost:4000
npm run dev           # con recarga automática

npm run test:e2e      # 52 pruebas de extremo a extremo (con el servidor en marcha)
npm run test          # 24 pruebas sin servidor: almacenamiento + función serverless
```

## Variables de entorno

| Variable | Por defecto | Para qué sirve |
|---|---|---|
| `PORT` | `4000` | Puerto HTTP |
| `JWT_ACCESS_SECRET` | — | Firma del access token (**cámbialo**) |
| `JWT_REFRESH_SECRET` | — | Firma de tokens de restablecimiento |
| `ACCESS_TOKEN_TTL` | `15m` | Vida del access token |
| `REFRESH_TOKEN_TTL_DAYS` | `30` | Vida del refresh token |
| `BCRYPT_ROUNDS` | `12` | Coste de hash (usa `10` en serverless) |
| `DATABASE_URL` | Postgres local | Cadena de conexión (pooler `:6543` en Supabase) |
| `PG_POOL_MAX` | `10` / `1` serverless | Conexiones por instancia |
| `STORAGE_DRIVER` | auto | `local` o `supabase` |
| `SUPABASE_URL` | — | Proyecto de Supabase (Storage) |
| `SUPABASE_SERVICE_ROLE_KEY` | — | Clave de servicio (**solo servidor**) |
| `SUPABASE_KYC_BUCKET` | `kyc` | Bucket privado de documentos |
| `DEMO_MODE` | `true` fuera de prod | Muestra el OTP y auto-aprueba el KYC |
| `MAX_LOGIN_ATTEMPTS` | `5` | Intentos antes de bloquear |
| `LOCK_MINUTES` | `15` | Duración del bloqueo |
| `OTP_TTL_MINUTES` | `5` | Caducidad del código |
| `OTP_MAX_ATTEMPTS` | `5` | Intentos por código |
| `OTP_RESEND_COOLDOWN_SECONDS` | `60` | Enfriamiento de reenvío |
| `MAX_PIN_ATTEMPTS` | `5` | Intentos de PIN |
| `MAX_UPLOAD_MB` | `8` | Tamaño máximo de imagen KYC |
| `KYC_AUTO_REVIEW_MS` | `10000` | Simulación de revisión (solo dev) |
| `EXPOSE_OTP_IN_RESPONSE` | `true` | Devuelve el OTP para pruebas (se fuerza a `false` en producción) |

## Ejemplo de flujo

```bash
# 1. Registro
curl -s -X POST localhost:4000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"firstName":"María","lastName":"González","email":"maria@test.app",
       "phone":"+584121234567","countryCode":"VE",
       "password":"Remesas2026$Seg","acceptedTerms":true}'

# 2. Verificar el OTP (devCode viene en la respuesta anterior)
curl -s -X POST localhost:4000/api/v1/auth/otp/verify \
  -H 'Content-Type: application/json' \
  -d '{"challengeId":"<id>","code":"<codigo>","deviceId":"demo-device-001"}'

# 3. Usar el access token
curl -s localhost:4000/api/v1/auth/me -H 'Authorization: Bearer <access>'
```

## Modelo de datos

| Tabla | Contenido |
|---|---|
| `users` | Perfil, hashes de contraseña y PIN, estado KYC, contadores de bloqueo |
| `otp_codes` | Códigos hasheados con propósito, caducidad e intentos |
| `refresh_tokens` | Tokens hasheados, rotación, revocación y detección de reuso |
| `devices` | Dispositivos de confianza y tokens biométricos |
| `kyc_submissions` | Expedientes de identidad y su resolución |
| `audit_logs` | Bitácora de seguridad para compliance |

Ningún secreto se guarda en claro: contraseñas y PIN con bcrypt; OTP, refresh
tokens y tokens biométricos con SHA-256.
