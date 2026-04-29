-- ============================================================
-- native-app/consumer_setup/02_setup_caller_grants.sql
-- Configures Caller Grants so the Native App's Streamlit can run
-- queries on behalf of the viewer using Restricted Caller's Rights.
--
-- KEY DIFFERENCE FROM SiS:
--   In the SiS standalone demo the account admin sets caller grants
--   for the app-owner role (STREAMLIT_OWNER_ROLE) — all in one account.
--
--   In the Native App model the CONSUMER account admin sets caller
--   grants targeting the APPLICATION itself.  The provider never
--   touches this configuration.  The consumer controls exactly what
--   their data the app is allowed to access via caller rights.
--
-- Run Step 1 as: ACCOUNTADMIN  (consumer account)
-- Run Step 2 as: SYSADMIN      (consumer account)
-- ============================================================

-- ── Step 1: Enable caller grant management ───────────────────
USE ROLE ACCOUNTADMIN;

GRANT MANAGE CALLER GRANTS ON ACCOUNT TO ROLE SYSADMIN;

-- ── Step 2: Grant caller privileges to the application ───────
USE ROLE SYSADMIN;

-- IMPORTANT: every object in the query path needs a CALLER grant.
-- The "restricted" in Restricted Caller Rights means the RCR connection
-- can ONLY access objects covered by an explicit CALLER grant — even if
-- the viewer's role has broader privileges in the consumer account.
--
-- Note: The syntax for targeting a Snowflake Native Application in
-- GRANT CALLER statements uses the APPLICATION keyword.
-- Replace SALES_DEMO_APP with the actual installed application name.

-- Database + schema visibility
GRANT CALLER USAGE ON DATABASE CONSUMER_DB
  TO APPLICATION SALES_DEMO_APP;

GRANT CALLER USAGE ON SCHEMA CONSUMER_DB.SALES
  TO APPLICATION SALES_DEMO_APP;

-- Table read (Row Access Policy will filter rows using the viewer's identity)
GRANT CALLER SELECT ON TABLE CONSUMER_DB.SALES.DEALS
  TO APPLICATION SALES_DEMO_APP;

-- Warehouse to run the query
GRANT CALLER USAGE ON WAREHOUSE CONSUMER_WH
  TO APPLICATION SALES_DEMO_APP;

-- ── Verify (should show 4 rows) ───────────────────────────────
SHOW CALLER GRANTS TO APPLICATION SALES_DEMO_APP;
