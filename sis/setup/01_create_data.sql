-- ============================================================
-- sis/setup/01_create_data.sql
-- Creates the SALES_DB database, SALES schema, and DEALS table,
-- then seeds it with sample data.
-- Run as: SYSADMIN (or a role with CREATE DATABASE privilege)
-- ============================================================

USE ROLE SYSADMIN;

-- ── Database & schema ─────────────────────────────────────────
CREATE DATABASE IF NOT EXISTS SALES_DB
  COMMENT = 'Demo database for the SiS RCR demo';

CREATE SCHEMA IF NOT EXISTS SALES_DB.SALES
  COMMENT = 'Sales data schema';

-- ── Deals table ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS SALES_DB.SALES.DEALS (
    deal_id   NUMBER AUTOINCREMENT PRIMARY KEY,
    rep_name  VARCHAR(100)   NOT NULL,   -- matches the Snowflake USERNAME of each rep
    region    VARCHAR(50)    NOT NULL,
    deal_name VARCHAR(200)   NOT NULL,
    amount    NUMBER(12, 2)  NOT NULL
)
COMMENT = 'Sales deals — Row Access Policy filters rows by rep_name = CURRENT_USER()';

-- ── Seed data (shared) ────────────────────────────────────────
INSERT INTO SALES_DB.SALES.DEALS (rep_name, region, deal_name, amount) VALUES
  ('ALICE_WEST',  'West', 'Acme Corp',        45000),
  ('ALICE_WEST',  'West', 'Widget Inc',        32000),
  ('BOB_EAST',    'East', 'Globex Corp',       78000),
  ('BOB_EAST',    'East', 'Initech',           55000),
  ('CAROL_EAST',  'East', 'Umbrella Corp',     91000),
  ('CAROL_EAST',  'East', 'Soylent Corp',      67000);

-- Verify
SELECT * FROM SALES_DB.SALES.DEALS ORDER BY rep_name, amount;
