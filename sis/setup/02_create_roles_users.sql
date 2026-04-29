-- ============================================================
-- sis/setup/02_create_roles_users.sql
-- Creates roles, a demo warehouse, and three demo users.
-- Run as: ACCOUNTADMIN
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ── Warehouse ──────────────────────────────────────────────────
CREATE WAREHOUSE IF NOT EXISTS DEMO_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME  = TRUE
    COMMENT = 'Shared warehouse for the RCR demo';

-- ── Roles ─────────────────────────────────────────────────────
-- Role that OWNS the Streamlit object.
-- Needs: CREATE STREAMLIT, USAGE on stage, compute pool, warehouse.
CREATE ROLE IF NOT EXISTS STREAMLIT_OWNER_ROLE
  COMMENT = 'Owns the SiS Streamlit app and all supporting objects';

-- Role granted to individual sales reps — limited visibility via Row Access Policy.
CREATE ROLE IF NOT EXISTS SALES_REP_ROLE
  COMMENT = 'Sales rep: sees only their own deals via Row Access Policy';

-- Role granted to managers — full visibility (RAP pass-through).
CREATE ROLE IF NOT EXISTS SALES_MANAGER_ROLE
  COMMENT = 'Sales manager: sees all deals (RAP pass-through)';

-- ── Role hierarchy ────────────────────────────────────────────
GRANT ROLE SALES_REP_ROLE     TO ROLE SYSADMIN;
GRANT ROLE SALES_MANAGER_ROLE TO ROLE SYSADMIN;
GRANT ROLE STREAMLIT_OWNER_ROLE TO ROLE SYSADMIN;

-- ── Warehouse grants ──────────────────────────────────────────
GRANT USAGE ON WAREHOUSE DEMO_WH TO ROLE STREAMLIT_OWNER_ROLE;
GRANT USAGE ON WAREHOUSE DEMO_WH TO ROLE SALES_REP_ROLE;
GRANT USAGE ON WAREHOUSE DEMO_WH TO ROLE SALES_MANAGER_ROLE;

-- ── Database / schema grants ─────────────────────────────────
GRANT USAGE ON DATABASE SALES_DB TO ROLE STREAMLIT_OWNER_ROLE;
GRANT USAGE ON DATABASE SALES_DB TO ROLE SALES_REP_ROLE;
GRANT USAGE ON DATABASE SALES_DB TO ROLE SALES_MANAGER_ROLE;

GRANT USAGE ON SCHEMA SALES_DB.SALES TO ROLE STREAMLIT_OWNER_ROLE;
GRANT USAGE ON SCHEMA SALES_DB.SALES TO ROLE SALES_REP_ROLE;
GRANT USAGE ON SCHEMA SALES_DB.SALES TO ROLE SALES_MANAGER_ROLE;

-- ── Table grants ──────────────────────────────────────────────
-- All roles get SELECT; the Row Access Policy (step 03) restricts rows.
GRANT SELECT ON TABLE SALES_DB.SALES.DEALS TO ROLE STREAMLIT_OWNER_ROLE;
GRANT SELECT ON TABLE SALES_DB.SALES.DEALS TO ROLE SALES_REP_ROLE;
GRANT SELECT ON TABLE SALES_DB.SALES.DEALS TO ROLE SALES_MANAGER_ROLE;

-- STREAMLIT_OWNER_ROLE also needs CREATE STREAMLIT and stage privileges
GRANT CREATE STREAMLIT ON SCHEMA SALES_DB.SALES TO ROLE STREAMLIT_OWNER_ROLE;
GRANT CREATE STAGE     ON SCHEMA SALES_DB.SALES TO ROLE STREAMLIT_OWNER_ROLE;

-- ── Users ─────────────────────────────────────────────────────
-- NOTE: Change LOGIN_NAME / PASSWORD as appropriate for your environment.
-- The rep_name column in DEALS matches the Snowflake USERNAME (not LOGIN_NAME).

CREATE USER IF NOT EXISTS ALICE_WEST
    LOGIN_NAME    = 'ALICE_WEST'
    DISPLAY_NAME  = 'Alice West (West Rep)'
    DEFAULT_ROLE  = SALES_REP_ROLE
    DEFAULT_WAREHOUSE = DEMO_WH
    MUST_CHANGE_PASSWORD = FALSE
    COMMENT = 'Demo user — West region sales rep';

CREATE USER IF NOT EXISTS BOB_EAST
    LOGIN_NAME    = 'BOB_EAST'
    DISPLAY_NAME  = 'Bob East (East Rep)'
    DEFAULT_ROLE  = SALES_REP_ROLE
    DEFAULT_WAREHOUSE = DEMO_WH
    MUST_CHANGE_PASSWORD = FALSE
    COMMENT = 'Demo user — East region sales rep';

CREATE USER IF NOT EXISTS CAROL_EAST
    LOGIN_NAME    = 'CAROL_EAST'
    DISPLAY_NAME  = 'Carol East (East Rep)'
    DEFAULT_ROLE  = SALES_REP_ROLE
    DEFAULT_WAREHOUSE = DEMO_WH
    MUST_CHANGE_PASSWORD = FALSE
    COMMENT = 'Demo user — East region sales rep';

CREATE USER IF NOT EXISTS SALES_MANAGER
    LOGIN_NAME    = 'SALES_MANAGER'
    DISPLAY_NAME  = 'Sales Manager'
    DEFAULT_ROLE  = SALES_MANAGER_ROLE
    DEFAULT_WAREHOUSE = DEMO_WH
    MUST_CHANGE_PASSWORD = FALSE
    COMMENT = 'Demo user — sales manager (sees all deals)';

-- ── Assign roles to users ─────────────────────────────────────
GRANT ROLE SALES_REP_ROLE     TO USER ALICE_WEST;
GRANT ROLE SALES_REP_ROLE     TO USER BOB_EAST;
GRANT ROLE SALES_REP_ROLE     TO USER CAROL_EAST;
GRANT ROLE SALES_MANAGER_ROLE TO USER SALES_MANAGER;
