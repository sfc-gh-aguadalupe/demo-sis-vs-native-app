-- ============================================================
-- native-app/consumer_setup/01_create_consumer_data.sql
-- Creates the consumer's own DEALS table in their account,
-- seeds it with sample data, and attaches a Row Access Policy
-- that filters rows based on the viewer's identity.
--
-- Run as: SYSADMIN (consumer account)
-- ============================================================

USE ROLE SYSADMIN;

-- ── Consumer database & schema ────────────────────────────────
CREATE DATABASE IF NOT EXISTS CONSUMER_DB
  COMMENT = 'Consumer-side database for the Native App RCR demo';

CREATE SCHEMA IF NOT EXISTS CONSUMER_DB.SALES
  COMMENT = 'Sales data schema — owned by the consumer';

-- ── Consumer warehouse (if not already present) ───────────────
CREATE WAREHOUSE IF NOT EXISTS CONSUMER_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND  = 60
  AUTO_RESUME   = TRUE
  COMMENT = 'Shared warehouse for the Native App RCR demo';

-- ── Consumer DEALS table ──────────────────────────────────────
-- NOTE: rep_name values must match the Snowflake USERNAMEs of
--       the consumer's users for CURRENT_USER()-based filtering to work.
CREATE TABLE IF NOT EXISTS CONSUMER_DB.SALES.DEALS (
    deal_id   NUMBER AUTOINCREMENT PRIMARY KEY,
    rep_name  VARCHAR(100)   NOT NULL,
    region    VARCHAR(50)    NOT NULL,
    deal_name VARCHAR(200)   NOT NULL,
    amount    NUMBER(12, 2)  NOT NULL
)
COMMENT = 'Consumer deals — Row Access Policy restricts rows by rep_name = CURRENT_USER()';

-- ── Seed data ─────────────────────────────────────────────────
-- Using the same rep names as the SiS demo so the same test users
-- (ALICE_WEST, BOB_EAST, CAROL_EAST, SALES_MANAGER) work in both flows.
-- In a real consumer account these would be the consumer's own users.
INSERT INTO CONSUMER_DB.SALES.DEALS (rep_name, region, deal_name, amount) VALUES
  ('ALICE_WEST',  'West', 'Acme Corp',        45000),
  ('ALICE_WEST',  'West', 'Widget Inc',        32000),
  ('BOB_EAST',    'East', 'Globex Corp',       78000),
  ('BOB_EAST',    'East', 'Initech',           55000),
  ('CAROL_EAST',  'East', 'Umbrella Corp',     91000),
  ('CAROL_EAST',  'East', 'Soylent Corp',      67000);

-- ── Consumer roles & users ────────────────────────────────────
CREATE ROLE IF NOT EXISTS CONSUMER_REP_ROLE
  COMMENT = 'Consumer sales rep — sees own deals only via RAP';

CREATE ROLE IF NOT EXISTS CONSUMER_MANAGER_ROLE
  COMMENT = 'Consumer manager — full visibility via RAP pass-through';

GRANT USAGE ON DATABASE CONSUMER_DB     TO ROLE CONSUMER_REP_ROLE;
GRANT USAGE ON SCHEMA   CONSUMER_DB.SALES TO ROLE CONSUMER_REP_ROLE;
GRANT SELECT ON TABLE   CONSUMER_DB.SALES.DEALS TO ROLE CONSUMER_REP_ROLE;

GRANT USAGE ON DATABASE CONSUMER_DB     TO ROLE CONSUMER_MANAGER_ROLE;
GRANT USAGE ON SCHEMA   CONSUMER_DB.SALES TO ROLE CONSUMER_MANAGER_ROLE;
GRANT SELECT ON TABLE   CONSUMER_DB.SALES.DEALS TO ROLE CONSUMER_MANAGER_ROLE;

GRANT USAGE ON WAREHOUSE CONSUMER_WH TO ROLE CONSUMER_REP_ROLE;
GRANT USAGE ON WAREHOUSE CONSUMER_WH TO ROLE CONSUMER_MANAGER_ROLE;

-- Create demo users (adjust LOGIN_NAME / PASSWORD as needed)
CREATE USER IF NOT EXISTS ALICE_WEST
  LOGIN_NAME = 'ALICE_WEST' DEFAULT_ROLE = CONSUMER_REP_ROLE
  DEFAULT_WAREHOUSE = CONSUMER_WH MUST_CHANGE_PASSWORD = FALSE;
CREATE USER IF NOT EXISTS BOB_EAST
  LOGIN_NAME = 'BOB_EAST' DEFAULT_ROLE = CONSUMER_REP_ROLE
  DEFAULT_WAREHOUSE = CONSUMER_WH MUST_CHANGE_PASSWORD = FALSE;
CREATE USER IF NOT EXISTS CAROL_EAST
  LOGIN_NAME = 'CAROL_EAST' DEFAULT_ROLE = CONSUMER_REP_ROLE
  DEFAULT_WAREHOUSE = CONSUMER_WH MUST_CHANGE_PASSWORD = FALSE;
CREATE USER IF NOT EXISTS SALES_MANAGER
  LOGIN_NAME = 'SALES_MANAGER' DEFAULT_ROLE = CONSUMER_MANAGER_ROLE
  DEFAULT_WAREHOUSE = CONSUMER_WH MUST_CHANGE_PASSWORD = FALSE;

GRANT ROLE CONSUMER_REP_ROLE     TO USER ALICE_WEST;
GRANT ROLE CONSUMER_REP_ROLE     TO USER BOB_EAST;
GRANT ROLE CONSUMER_REP_ROLE     TO USER CAROL_EAST;
GRANT ROLE CONSUMER_MANAGER_ROLE TO USER SALES_MANAGER;

-- ── Row Access Policy ─────────────────────────────────────────
-- Same logic as the SiS demo: managers see all; reps see their own rows.
-- With RCR the callers-rights connection uses the VIEWER's default role,
-- so CURRENT_ROLE() reflects the consumer user's actual role.
CREATE OR REPLACE ROW ACCESS POLICY CONSUMER_DB.SALES.DEALS_RAP
  AS (rep_name VARCHAR) RETURNS BOOLEAN ->
  CASE
    WHEN IS_ROLE_IN_SESSION('CONSUMER_MANAGER_ROLE') THEN TRUE
    WHEN IS_ROLE_IN_SESSION('SYSADMIN')              THEN TRUE
    WHEN IS_ROLE_IN_SESSION('ACCOUNTADMIN')          THEN TRUE
    ELSE rep_name = CURRENT_USER()
  END
  COMMENT = 'Filters consumer deals to the calling user unless they hold a manager role';

ALTER TABLE CONSUMER_DB.SALES.DEALS
  ADD ROW ACCESS POLICY CONSUMER_DB.SALES.DEALS_RAP ON (rep_name);

SELECT COUNT(*) AS total_deals FROM CONSUMER_DB.SALES.DEALS;
