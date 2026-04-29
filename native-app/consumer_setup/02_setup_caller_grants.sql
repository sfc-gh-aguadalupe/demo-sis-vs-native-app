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

-- Allow the app's Streamlit to SELECT from the consumer's DEALS table
-- on behalf of the viewer.  The Row Access Policy will then filter rows
-- using the VIEWER's identity — not the application's identity.
--
-- Note: The syntax for targeting a Snowflake Native Application in
-- GRANT CALLER statements is the same as for a regular role, using
-- the APPLICATION keyword.  Replace SALES_DEMO_APP with the actual
-- installed application name if you changed it.
GRANT CALLER SELECT ON TABLE CONSUMER_DB.SALES.DEALS
  TO APPLICATION SALES_DEMO_APP;

-- Allow the app's Streamlit to use the consumer warehouse on behalf
-- of the viewer.
GRANT CALLER USAGE ON WAREHOUSE CONSUMER_WH
  TO APPLICATION SALES_DEMO_APP;

-- ── Verify ───────────────────────────────────────────────────
SHOW CALLER GRANTS TO APPLICATION SALES_DEMO_APP;
