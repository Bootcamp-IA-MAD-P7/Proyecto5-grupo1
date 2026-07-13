-- V2__seed_admin.sql
-- Crea el usuario IT_ADMIN inicial.
-- Contraseña: Admin1234! (BCrypt, coste 12)
-- CAMBIAR en producción vía variable de entorno o gestión interna.

INSERT INTO users (id, email, password_hash, full_name, role, locale, active)
VALUES (
    uuid_generate_v4(),
    'admin@sentilife.com',
    '$2a$12$9nLTv4kJMGYZ3F5s8e7A0.v5xGQKtXHR3UxNJq3a1LVpJW8z6sG9C',
    'IT Admin',
    'IT_ADMIN',
    'es',
    TRUE
)
ON CONFLICT (email) DO NOTHING;
