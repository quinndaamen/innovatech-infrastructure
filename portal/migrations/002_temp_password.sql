-- Temporary Keycloak password, shown once to the HR admin after onboarding, then cleared.
ALTER TABLE employees ADD COLUMN IF NOT EXISTS temp_password TEXT;
