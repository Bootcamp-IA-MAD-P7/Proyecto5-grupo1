-- V4__fix_admin_password.sql
-- V2 seed inserted a BCrypt hash that does not match documented password Admin1234!
-- Regenerate with pgcrypto (compatible with Spring BCryptPasswordEncoder).

CREATE EXTENSION IF NOT EXISTS pgcrypto;

UPDATE users
SET password_hash = crypt('Admin1234!', gen_salt('bf', 12))
WHERE email = 'admin@sentilife.com';
