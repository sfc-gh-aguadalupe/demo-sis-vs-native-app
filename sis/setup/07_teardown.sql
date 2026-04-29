-- ============================================================
-- sis/setup/07_teardown.sql
-- Removes ALL objects created by the SiS demo setup scripts.
-- Run as: ACCOUNTADMIN
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ── Streamlit + stage ─────────────────────────────────────────
DROP STREAMLIT  IF EXISTS SALES_DB.SALES.DEALS_APP;
DROP STAGE      IF EXISTS SALES_DB.SALES.STREAMLIT_STAGE;

-- ── Row Access Policy ─────────────────────────────────────────
-- Must detach from the table before dropping
ALTER TABLE SALES_DB.SALES.DEALS
  DROP ROW ACCESS POLICY SALES_DB.SALES.DEALS_RAP;
DROP ROW ACCESS POLICY IF EXISTS SALES_DB.SALES.DEALS_RAP;

-- ── Table ─────────────────────────────────────────────────────
DROP TABLE IF EXISTS SALES_DB.SALES.DEALS;

-- ── Schema + database ─────────────────────────────────────────
DROP SCHEMA   IF EXISTS SALES_DB.SALES;
DROP DATABASE IF EXISTS SALES_DB;

-- ── Caller grants ─────────────────────────────────────────────
REVOKE CALLER SELECT ON TABLE SALES_DB.SALES.DEALS
  FROM ROLE STREAMLIT_OWNER_ROLE;   -- will no-op if table already dropped
REVOKE CALLER USAGE ON WAREHOUSE DEMO_WH
  FROM ROLE STREAMLIT_OWNER_ROLE;

-- ── Users ─────────────────────────────────────────────────────
DROP USER IF EXISTS ALICE_WEST;
DROP USER IF EXISTS BOB_EAST;
DROP USER IF EXISTS CAROL_EAST;
DROP USER IF EXISTS SALES_MANAGER;

-- ── Roles ─────────────────────────────────────────────────────
DROP ROLE IF EXISTS SALES_REP_ROLE;
DROP ROLE IF EXISTS SALES_MANAGER_ROLE;
DROP ROLE IF EXISTS STREAMLIT_OWNER_ROLE;

-- ── EAI (optional) ────────────────────────────────────────────
DROP INTEGRATION IF EXISTS PYPI_ACCESS_INTEGRATION;

-- ── Warehouse ─────────────────────────────────────────────────
-- Only drop if you created it specifically for this demo.
-- Comment this out if DEMO_WH is shared with other workloads.
DROP WAREHOUSE IF EXISTS DEMO_WH;
