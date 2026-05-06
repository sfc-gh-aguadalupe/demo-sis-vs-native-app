-- ============================================================
-- native-app/consumer_setup/03_grant_to_app.sql
-- Grants the installed Native App:
--   1. Direct access to the consumer's DEALS table
--   2. A compute pool for running the SPCS service
--   3. BIND SERVICE ENDPOINT for public web access
--   4. Warehouse usage for queries
--
-- This is separate from Caller Grants (step 02).  Both are needed:
--
--   This script  → tells Snowflake the APP is allowed to read DEALS
--                  and run its SPCS service
--   Step 02      → tells Snowflake the APP may run that read using
--                  the VIEWER's identity (Restricted Caller's Rights)
--
-- Run as: ACCOUNTADMIN  (consumer account)
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ── 1. Create a compute pool for the app ──────────────────────
-- FOR APPLICATION restricts this pool to the specified app only.
-- CPU_X64_S is the smallest instance family suitable for a single
-- Streamlit container.
CREATE COMPUTE POOL IF NOT EXISTS SALES_DEMO_POOL
  FOR APPLICATION SALES_DEMO_APP
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_S
  AUTO_RESUME = TRUE
  AUTO_SUSPEND_SECS = 300
  COMMENT = 'Compute pool for the Sales Demo Native App SPCS service';

-- ── 2. Grant SPCS privileges to the app ───────────────────────
GRANT USAGE ON COMPUTE POOL SALES_DEMO_POOL
  TO APPLICATION SALES_DEMO_APP;

GRANT BIND SERVICE ENDPOINT ON ACCOUNT
  TO APPLICATION SALES_DEMO_APP;

-- ── 3. Grant data access to the app ──────────────────────────
GRANT USAGE ON DATABASE CONSUMER_DB
  TO APPLICATION SALES_DEMO_APP;

GRANT USAGE ON SCHEMA CONSUMER_DB.SALES
  TO APPLICATION SALES_DEMO_APP;

GRANT SELECT ON TABLE CONSUMER_DB.SALES.DEALS
  TO APPLICATION SALES_DEMO_APP;

-- ── 4. Grant warehouse usage ──────────────────────────────────
GRANT USAGE ON WAREHOUSE CONSUMER_WH
  TO APPLICATION SALES_DEMO_APP;

-- ── 5. Start the service ──────────────────────────────────────
-- The app exposes a start_app procedure that creates the SPCS service.
CALL SALES_DEMO_APP.core.start_app('SALES_DEMO_POOL', 'CONSUMER_WH');

-- ── Verify ───────────────────────────────────────────────────
SHOW GRANTS TO APPLICATION SALES_DEMO_APP;
CALL SALES_DEMO_APP.core.app_url();
