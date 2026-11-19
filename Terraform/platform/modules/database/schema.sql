-- Schema for the portal database on Cloud SQL (PostgreSQL).
-- Safe to run more than once: every statement uses IF NOT EXISTS.

-- The people Innovatech onboards and offboards.
-- 'role' decides which desktop image is deployed.
CREATE TABLE IF NOT EXISTS employees (
  id          SERIAL PRIMARY KEY,
  name        TEXT NOT NULL,
  email       TEXT NOT NULL UNIQUE,
  department  TEXT NOT NULL,
  role        TEXT NOT NULL CHECK (role IN ('hr-admin','hr-staff','admin','developer')),
  status      TEXT NOT NULL DEFAULT 'pending'
              CHECK (status IN ('pending','active','failed','offboarded')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- The desktop (Helm release) that belongs to an employee.
CREATE TABLE IF NOT EXISTS desktops (
  id            SERIAL PRIMARY KEY,
  employee_id   INTEGER NOT NULL REFERENCES employees(id),
  release_name  TEXT NOT NULL,
  hostname      TEXT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Audit trail: who did what to whom, and when (REQ-01).
CREATE TABLE IF NOT EXISTS audit_log (
  id          SERIAL PRIMARY KEY,
  actor       TEXT NOT NULL,
  action      TEXT NOT NULL,
  target      TEXT,
  details     TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);