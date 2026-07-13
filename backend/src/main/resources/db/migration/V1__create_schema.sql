-- V1__create_schema.sql
-- Esquema inicial de SentiLife según spec §5.1
-- Flyway aplica este script una sola vez al arrancar la aplicación.

-- ── Extensión UUID ──────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── users ───────────────────────────────────────────────────────────────────
CREATE TABLE users (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email         VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name     VARCHAR(255) NOT NULL,
    role          VARCHAR(20)  NOT NULL CHECK (role IN ('MONITORED', 'CAREGIVER', 'IT_ADMIN')),
    locale        VARCHAR(10)  NOT NULL DEFAULT 'es',
    active        BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── monitored_persons ────────────────────────────────────────────────────────
-- Un CAREGIVER registra personas; opcionalmente la persona tiene cuenta propia (user_id).
CREATE TABLE monitored_persons (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    caregiver_id      UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_id           UUID                  REFERENCES users(id) ON DELETE SET NULL, -- cuenta propia (opcional)
    full_name         VARCHAR(255) NOT NULL,
    birth_date        DATE         NOT NULL,
    sex               VARCHAR(10)  NOT NULL CHECK (sex IN ('M', 'F', 'OTHER')),
    weight_kg         DECIMAL(5,2),
    height_cm         DECIMAL(5,2),
    emergency_contact VARCHAR(50),
    pairing_code      VARCHAR(20)  UNIQUE,                                            -- código de vinculación OTP
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── consents ─────────────────────────────────────────────────────────────────
CREATE TABLE consents (
    id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    monitored_person_id  UUID        NOT NULL REFERENCES monitored_persons(id) ON DELETE CASCADE,
    policy_version       VARCHAR(20) NOT NULL,                                        -- ej. "1.0-es"
    status               VARCHAR(10) NOT NULL CHECK (status IN ('ACTIVE', 'REVOKED')),
    accepted_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at           TIMESTAMPTZ
);

-- Solo puede haber un consentimiento ACTIVE por persona
CREATE UNIQUE INDEX idx_consents_active
    ON consents(monitored_person_id)
    WHERE status = 'ACTIVE';

-- ── alerts ────────────────────────────────────────────────────────────────────
CREATE TABLE alerts (
    id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    monitored_person_id  UUID           NOT NULL REFERENCES monitored_persons(id) ON DELETE CASCADE,
    detected_at          TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    confidence           DECIMAL(5,4)   NOT NULL CHECK (confidence BETWEEN 0 AND 1),
    model_version        VARCHAR(50)    NOT NULL,
    status               VARCHAR(10)    NOT NULL DEFAULT 'PENDING'
                             CHECK (status IN ('PENDING', 'CONFIRMED', 'DISMISSED')),
    reviewed_by          UUID                    REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at          TIMESTAMPTZ,
    -- Referencia a la ventana en PostgreSQL (fallback ADR-03)
    telemetry_window_id  UUID
);

-- ── feedback_labels ───────────────────────────────────────────────────────────
CREATE TABLE feedback_labels (
    id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    alert_id              UUID        NOT NULL REFERENCES alerts(id) ON DELETE CASCADE,
    label                 VARCHAR(15) NOT NULL CHECK (label IN ('TRUE_FALL', 'FALSE_ALARM')),
    comment               TEXT,
    telemetry_window_ref  VARCHAR(255),                                               -- ref a ventana en InfluxDB (futuro)
    created_by            UUID        NOT NULL REFERENCES users(id),
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── telemetry_windows ─────────────────────────────────────────────────────────
-- Fallback ADR-03: telemetría en PostgreSQL hasta integrar InfluxDB.
CREATE TABLE telemetry_windows (
    id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    monitored_person_id  UUID         NOT NULL REFERENCES monitored_persons(id) ON DELETE CASCADE,
    device_id            VARCHAR(255) NOT NULL,
    window_start         TIMESTAMPTZ  NOT NULL,
    window_end           TIMESTAMPTZ  NOT NULL,
    sample_rate_hz       INTEGER      NOT NULL,
    -- Señales serializadas como JSON (simple para el fallback)
    samples_json         JSONB        NOT NULL,
    context_json         JSONB,
    -- Resultado de inferencia
    fall_detected        BOOLEAN,
    confidence           DECIMAL(5,4),
    model_version        VARCHAR(50),
    latency_ms           INTEGER,
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_telemetry_windows_person ON telemetry_windows(monitored_person_id, window_start DESC);

-- ── paired_devices ────────────────────────────────────────────────────────────
CREATE TABLE paired_devices (
    id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    monitored_person_id  UUID         NOT NULL REFERENCES monitored_persons(id) ON DELETE CASCADE,
    device_id            VARCHAR(255) NOT NULL,
    platform             VARCHAR(10)  NOT NULL CHECK (platform IN ('ANDROID', 'IOS')),
    device_token_hash    VARCHAR(255),
    paired_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    active               BOOLEAN      NOT NULL DEFAULT TRUE,
    UNIQUE (monitored_person_id, device_id)
);

-- ── push_tokens ───────────────────────────────────────────────────────────────
-- Token FCM del dispositivo del CAREGIVER para notificaciones push.
CREATE TABLE push_tokens (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id   VARCHAR(255) NOT NULL,
    fcm_token   TEXT         NOT NULL,
    platform    VARCHAR(10)  NOT NULL CHECK (platform IN ('ANDROID', 'IOS')),
    locale      VARCHAR(10)  NOT NULL DEFAULT 'es',
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, device_id)
);

-- ── model_registry ────────────────────────────────────────────────────────────
CREATE TABLE model_registry (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    version       VARCHAR(50)  NOT NULL UNIQUE,                                       -- ej. "xgb-1.2.0"
    algorithm     VARCHAR(50)  NOT NULL,
    metrics_json  JSONB        NOT NULL,                                              -- recall, f1, accuracy, etc.
    artifact_uri  VARCHAR(500) NOT NULL,                                              -- ruta al .pkl
    status        VARCHAR(10)  NOT NULL DEFAULT 'CANDIDATE'
                      CHECK (status IN ('CANDIDATE', 'ACTIVE', 'RETIRED')),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Solo puede haber un modelo ACTIVE a la vez
CREATE UNIQUE INDEX idx_model_registry_active
    ON model_registry(status)
    WHERE status = 'ACTIVE';

-- ── app_versions (OTA — existente, mantenida) ─────────────────────────────────
CREATE TABLE IF NOT EXISTS app_versions (
    id            SERIAL PRIMARY KEY,
    version_code  INTEGER      NOT NULL UNIQUE,
    version_name  VARCHAR(20)  NOT NULL,
    apk_url       TEXT         NOT NULL,
    release_notes TEXT,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
