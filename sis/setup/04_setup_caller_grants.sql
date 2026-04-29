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

-- Apps owned by STREAMLIT_OWNER_ROLE may SELECT from DEALS on behalf
-- of the caller (viewer).  The Row Access Policy will then filter rows
-- using the VIEWER's CURRENT_USER() / CURRENT_ROLE() — not the owner's.
GRANT CALLER SELECT ON TABLE SALES_DB.SALES.DEALS
  TO ROLE STREAMLIT_OWNER_ROLE;

-- Apps owned by STREAMLIT_OWNER_ROLE may use DEMO_WH on behalf of
-- the caller.  Required for any query the callers-rights connection runs.
GRANT CALLER USAGE ON WAREHOUSE DEMO_WH
  TO ROLE STREAMLIT_OWNER_ROLE;

-- ── Verify ───────────────────────────────────────────────────
SHOW CALLER GRANTS TO ROLE STREAMLIT_OWNER_ROLE;
