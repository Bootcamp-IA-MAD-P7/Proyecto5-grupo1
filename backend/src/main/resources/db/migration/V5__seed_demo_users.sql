-- V5__seed_demo_users.sql
-- Usuarios demo QA: CAREGIVER + MONITORED (misma contraseña que IT_ADMIN).
-- Contraseña: Admin1234!

CREATE EXTENSION IF NOT EXISTS pgcrypto;

INSERT INTO users (id, email, password_hash, full_name, role, locale, active)
VALUES
    (
        uuid_generate_v4(),
        'caregiver@sentilife.com',
        crypt('Admin1234!', gen_salt('bf', 12)),
        'Demo Caregiver',
        'CAREGIVER',
        'es',
        TRUE
    ),
    (
        uuid_generate_v4(),
        'monitored@sentilife.com',
        crypt('Admin1234!', gen_salt('bf', 12)),
        'Demo Monitored',
        'MONITORED',
        'es',
        TRUE
    )
ON CONFLICT (email) DO NOTHING;
