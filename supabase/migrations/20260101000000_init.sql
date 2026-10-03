-- ════════════════════════════════════════════════════════════════
--  Esquema de autenticación · App de remesas
--  PostgreSQL / Supabase · todas las fechas en texto ISO-8601 UTC
--
--  Se aplica con:
--    supabase db push            (CLI de Supabase)
--    npm run migrate --prefix backend   (conexión directa)
-- ════════════════════════════════════════════════════════════════

-- Marca de tiempo en el mismo formato que usa la API (ISO-8601 con Z).
CREATE OR REPLACE FUNCTION app_now() RETURNS TEXT
  LANGUAGE sql STABLE AS
$$ SELECT to_char((now() AT TIME ZONE 'utc'), 'YYYY-MM-DD"T"HH24:MI:SS"Z"') $$;

-- ───────────────────────── Usuarios ─────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id                     TEXT PRIMARY KEY,
  first_name             TEXT NOT NULL,
  last_name              TEXT NOT NULL,
  email                  TEXT NOT NULL UNIQUE,
  phone                  TEXT NOT NULL UNIQUE,
  country_code           TEXT NOT NULL DEFAULT 'US',
  password_hash          TEXT NOT NULL,
  pin_hash               TEXT,
  status                 TEXT NOT NULL DEFAULT 'pending_verification'
                           CHECK (status IN ('pending_verification','active','locked','suspended')),
  email_verified         INTEGER NOT NULL DEFAULT 0,
  phone_verified         INTEGER NOT NULL DEFAULT 0,
  kyc_level              INTEGER NOT NULL DEFAULT 0,
  kyc_status             TEXT NOT NULL DEFAULT 'not_started'
                           CHECK (kyc_status IN ('not_started','pending','in_review','approved','rejected')),
  failed_login_attempts  INTEGER NOT NULL DEFAULT 0,
  failed_pin_attempts    INTEGER NOT NULL DEFAULT 0,
  locked_until           TEXT,
  last_login_at          TEXT,
  created_at             TEXT NOT NULL DEFAULT app_now(),
  updated_at             TEXT NOT NULL DEFAULT app_now()
);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);

-- ───────────── Códigos OTP (nunca en texto plano) ─────────────
CREATE TABLE IF NOT EXISTS otp_codes (
  id           TEXT PRIMARY KEY,
  user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  purpose      TEXT NOT NULL CHECK (purpose IN ('register','login','password_reset','transaction')),
  channel      TEXT NOT NULL DEFAULT 'sms' CHECK (channel IN ('sms','email')),
  code_hash    TEXT NOT NULL,
  attempts     INTEGER NOT NULL DEFAULT 0,
  expires_at   TEXT NOT NULL,
  consumed_at  TEXT,
  created_at   TEXT NOT NULL DEFAULT app_now()
);
CREATE INDEX IF NOT EXISTS idx_otp_user_purpose ON otp_codes(user_id, purpose);

-- ──────── Refresh tokens con rotación y detección de reuso ────────
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id           TEXT PRIMARY KEY,
  user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash   TEXT NOT NULL UNIQUE,
  device_id    TEXT,
  user_agent   TEXT,
  ip           TEXT,
  expires_at   TEXT NOT NULL,
  revoked_at   TEXT,
  replaced_by  TEXT,
  created_at   TEXT NOT NULL DEFAULT app_now()
);
CREATE INDEX IF NOT EXISTS idx_refresh_user ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_refresh_hash ON refresh_tokens(token_hash);

-- ───────── Dispositivos de confianza / biometría ─────────
CREATE TABLE IF NOT EXISTS devices (
  id                    TEXT PRIMARY KEY,
  user_id               TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id             TEXT NOT NULL,
  device_name           TEXT,
  platform              TEXT,
  biometric_token_hash  TEXT,
  biometric_enabled     INTEGER NOT NULL DEFAULT 0,
  trusted               INTEGER NOT NULL DEFAULT 0,
  last_seen_at          TEXT,
  created_at            TEXT NOT NULL DEFAULT app_now(),
  UNIQUE (user_id, device_id)
);

-- ───────────────────── Expedientes KYC ─────────────────────
-- Las imágenes viven en Supabase Storage (bucket privado "kyc");
-- aquí solo se guarda su ruta.
CREATE TABLE IF NOT EXISTS kyc_submissions (
  id                  TEXT PRIMARY KEY,
  user_id             TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  document_type       TEXT NOT NULL CHECK (document_type IN ('passport','national_id','drivers_license')),
  document_number     TEXT NOT NULL,
  birth_date          TEXT,
  address             TEXT,
  document_front_path TEXT NOT NULL,
  document_back_path  TEXT,
  selfie_path         TEXT NOT NULL,
  status              TEXT NOT NULL DEFAULT 'in_review'
                        CHECK (status IN ('in_review','approved','rejected')),
  rejection_reason    TEXT,
  reviewed_at         TEXT,
  created_at          TEXT NOT NULL DEFAULT app_now()
);
CREATE INDEX IF NOT EXISTS idx_kyc_user ON kyc_submissions(user_id);

-- ───────── Bitácora de seguridad (auditoría / compliance) ─────────
CREATE TABLE IF NOT EXISTS audit_logs (
  id          TEXT PRIMARY KEY,
  user_id     TEXT,
  event       TEXT NOT NULL,
  ip          TEXT,
  user_agent  TEXT,
  metadata    TEXT,
  created_at  TEXT NOT NULL DEFAULT app_now()
);
CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_logs(user_id, created_at);

-- ════════════════════════════════════════════════════════════════
--  Blindaje en Supabase
--
--  Supabase publica automáticamente las tablas de `public` a través
--  de PostgREST con la clave anónima. Estas tablas guardan hashes de
--  contraseñas, PIN y tokens: NADIE debe poder leerlas desde el
--  navegador. Solo la API (que entra por conexión directa como dueña
--  de las tablas) las toca.
-- ════════════════════════════════════════════════════════════════
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['users','otp_codes','refresh_tokens','devices','kyc_submissions','audit_logs']
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    -- Sin políticas = denegado por defecto para anon y authenticated.
    EXECUTE format('REVOKE ALL ON TABLE %I FROM anon, authenticated', t);
  END LOOP;
EXCEPTION
  WHEN undefined_object THEN
    -- Fuera de Supabase los roles anon/authenticated no existen: no pasa nada.
    RAISE NOTICE 'Roles anon/authenticated no encontrados; se omite el REVOKE.';
END $$;
