-- V6__link_demo_monitored_user.sql
-- Every monitored profile must belong to one real MONITORED account.
-- This migration is intended for a fresh development database: existing
-- orphan rows deliberately make SET NOT NULL fail instead of being deleted.

INSERT INTO monitored_persons (
    id,
    caregiver_id,
    user_id,
    full_name,
    birth_date,
    sex,
    weight_kg,
    height_cm,
    emergency_contact,
    pairing_code
)
SELECT
    uuid_generate_v4(),
    caregiver.id,
    monitored.id,
    monitored.full_name,
    DATE '1950-01-01',
    'OTHER',
    70.00,
    170.00,
    NULL,
    'SL-DEMO01'
FROM users caregiver
CROSS JOIN users monitored
WHERE caregiver.email = 'caregiver@sentilife.com'
  AND caregiver.role = 'CAREGIVER'
  AND monitored.email = 'monitored@sentilife.com'
  AND monitored.role = 'MONITORED'
  AND NOT EXISTS (
      SELECT 1
      FROM monitored_persons existing
      WHERE existing.user_id = monitored.id
  );

ALTER TABLE monitored_persons
    DROP CONSTRAINT monitored_persons_user_id_fkey;

ALTER TABLE monitored_persons
    ALTER COLUMN user_id SET NOT NULL;

ALTER TABLE monitored_persons
    ADD CONSTRAINT uq_monitored_persons_user_id UNIQUE (user_id);

ALTER TABLE monitored_persons
    ADD CONSTRAINT fk_monitored_persons_user
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;
