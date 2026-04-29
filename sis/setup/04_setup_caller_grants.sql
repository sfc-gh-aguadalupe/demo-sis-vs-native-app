-- ============================================================
-- sis/setup/04_setup_caller_grants.sql
-- Configures Caller Grants so the Streamlit app (owned by
-- STREAMLIT_OWNER_ROLE) can run queries on behalf of the viewer
-- using Restricted Caller's Rights.
--
-- Caller Grants are an account-level configuration that tell
-- Snowflake which tables and warehouses a given app owner role
-- is ALLOWED to access under the viewer's identity.
--
-- Without these grants the st.connection("snowflake-callers-rights")
-- connection will fail with an authorization error.
--
-- Run Step 1 as: ACCOUNTADMIN
-- Run Step 2 as: SYSADMIN
-- ============================================================

-- ── Step 1: Allow SYSADMIN to manage caller grants ───────────
USE ROLE ACCOUNTADMIN;

GRANT MANAGE CALLER GRANTS ON ACCOUNT TO ROLE SYSADMIN
  COMMENT = 'Lets SYSADMIN define which caller privileges app owners can use';

-- ── Step 2: Grant specific caller privileges ─────────────────
USE ROLE SYSADMIN;

-- IMPORTANT: every object in the query path needs a CALLER grant.
-- The "restricted" in Restricted Caller Rights means the RCR connection
-- can ONLY access objects covered by an explicit CALLER grant — even if
-- the viewer's role has broader privileges in the account.

-- Database + schema visibility
GRANT CALLER USAGE ON DATABASE SALES_DB TO ROLE STREAMLIT_OWNER_ROLE;
GRANT CALLER USAGE ON SCHEMA SALES_DB.SALES TO ROLE STREAMLIT_OWNER_ROLE;

-- Table read
GRANT CALLER SELECT ON TABLE SALES_DB.SALES.DEALS TO ROLE STREAMLIT_OWNER_ROLE;

-- Warehouse to run the query
GRANT CALLER USAGE ON WAREHOUSE DEMO_WH TO ROLE STREAMLIT_OWNER_ROLE;

-- ── Verify (should show 4 rows) ───────────────────────────────
SHOW CALLER GRANTS TO ROLE STREAMLIT_OWNER_ROLE;
