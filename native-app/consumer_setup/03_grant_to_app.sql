-- ============================================================
-- native-app/consumer_setup/03_grant_to_app.sql
-- Grants the installed Native App direct access to the consumer's
-- DEALS table so that the Streamlit can query it.
--
-- This is separate from Caller Grants (step 02).  Both are needed:
--
--   This script  → tells Snowflake the APP is allowed to read DEALS
--   Step 02      → tells Snowflake the APP may run that read using
--                  the VIEWER's identity (Restricted Caller's Rights)
--
-- Without this script the app gets a "Insufficient privileges" error
-- even if caller grants are configured.
-- Without step 02 the callers-rights connection gets an auth error.
--
-- Run as: ACCOUNTADMIN or object owner  (consumer account)
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ── Grant the app read access to the consumer's data ─────────
GRANT USAGE ON DATABASE CONSUMER_DB
  TO APPLICATION SALES_DEMO_APP;

GRANT USAGE ON SCHEMA CONSUMER_DB.SALES
  TO APPLICATION SALES_DEMO_APP;

GRANT SELECT ON TABLE CONSUMER_DB.SALES.DEALS
  TO APPLICATION SALES_DEMO_APP;

-- ── Verify ───────────────────────────────────────────────────
SHOW GRANTS TO APPLICATION SALES_DEMO_APP;
