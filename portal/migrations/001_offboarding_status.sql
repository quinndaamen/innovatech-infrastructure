-- The worker needs an 'offboarding' state between 'active' and 'offboarded'.
ALTER TABLE employees DROP CONSTRAINT IF EXISTS employees_status_check;
ALTER TABLE employees ADD CONSTRAINT employees_status_check
  CHECK (status IN ('pending','active','failed','offboarding','offboarded'));