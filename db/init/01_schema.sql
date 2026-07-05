-- Fall-Sentinel — esquema PostgreSQL local (docker-compose)
-- Tabla usada por /app/latest-version y /app/register-version

CREATE TABLE IF NOT EXISTS app_versions (
    id SERIAL PRIMARY KEY,
    version_code INTEGER NOT NULL UNIQUE,
    version_name VARCHAR(50) NOT NULL,
    apk_url TEXT NOT NULL,
    release_notes TEXT,
    min_supported_version_code INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_versions_code ON app_versions (version_code DESC);

INSERT INTO app_versions (version_code, version_name, apk_url, release_notes)
VALUES (1, '1.0.0-local', 'http://localhost:8000/health', 'Seed local')
ON CONFLICT (version_code) DO NOTHING;
