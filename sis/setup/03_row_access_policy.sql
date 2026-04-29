-- ============================================================
-- sis/setup/03_row_access_policy.sql
-- Creates and attaches a Row Access Policy to DEALS.
--
-- Policy logic:
--   SALES_MANAGER_ROLE    → full pass-through (sees all rows)
--   STREAMLIT_OWNER_ROLE  → full pass-through (app owner panel shows all)
--   SYSADMIN / ACCOUNTADMIN → pass-through (admin access)
--   Everyone else         → only rows where rep_name = CURRENT_USER()
--
-- With RCR, CURRENT_USER() on the callers-rights connection returns the
-- VIEWER's Snowflake username — so each rep sees only their own deals.
-- Run as: SYSADMIN (needs CREATE ROW ACCESS POLICY on schema)
-- ============================================================

USE ROLE SYSADMIN;
USE DATABASE SALES_DB;
USE SCHEMA SALES;

-- ── Create the policy ─────────────────────────────────────────
CREATE OR REPLACE ROW ACCESS POLICY sales_db.sales.deals_rap
  AS (rep_name VARCHAR) RETURNS BOOLEAN ->
  CASE
    WHEN IS_ROLE_IN_SESSION('SALES_MANAGER_ROLE')   THEN TRUE
    WHEN IS_ROLE_IN_SESSION('STREAMLIT_OWNER_ROLE') THEN TRUE
    WHEN IS_ROLE_IN_SESSION('SYSADMIN')             THEN TRUE
    WHEN IS_ROLE_IN_SESSION('ACCOUNTADMIN')         THEN TRUE
    ELSE rep_name = CURRENT_USER()
  END
  COMMENT = 'Filters deals to the calling user unless they hold a manager or admin role';

-- ── Attach to DEALS ───────────────────────────────────────────
ALTER TABLE sales_db.sales.deals
  ADD ROW ACCESS POLICY sales_db.sales.deals_rap ON (rep_name);

-- ── Smoke test ────────────────────────────────────────────────
-- Run the next two lines while acting as different roles to verify:
--   USE ROLE SALES_REP_ROLE;   → should return 0 rows (no user named SYSADMIN in DEALS)
--   USE ROLE SALES_MANAGER_ROLE; → should return 6 rows
SELECT COUNT(*) AS visible_rows FROM sales_db.sales.deals;
