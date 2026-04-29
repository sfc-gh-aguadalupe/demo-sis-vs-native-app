-- ============================================================
-- native-app/app/setup_script.sql
-- Runs automatically when a consumer installs or upgrades the app.
-- Creates application roles, the core schema, and the Streamlit.
--
-- The Streamlit uses SYSTEM_COMPUTE_POOL_CPU — the system-managed
-- CPU compute pool present in every Snowflake account. No consumer-
-- side compute pool provisioning is required.
--
-- After installation the consumer must run the scripts in
-- consumer_setup/ to grant data access and configure caller grants.
-- ============================================================

-- ── Application roles ─────────────────────────────────────────
-- APP_ADMIN : installs, configures, and manages the application
-- APP_USER  : end-users who open the Streamlit dashboard
CREATE APPLICATION ROLE IF NOT EXISTS APP_ADMIN;
CREATE APPLICATION ROLE IF NOT EXISTS APP_USER;

-- ── Core schema ───────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS core;

GRANT USAGE ON SCHEMA core TO APPLICATION ROLE APP_ADMIN;
GRANT USAGE ON SCHEMA core TO APPLICATION ROLE APP_USER;

-- ── Streamlit app (container runtime) ────────────────────────
-- FROM '/streamlit' maps to the /streamlit/ directory on the app stage,
-- which corresponds to native-app/app/streamlit/ in this repository.
--
-- SYSTEM_COMPUTE_POOL_CPU is a Snowflake-managed compute pool:
--   Instance family : CPU_X64_S
--   Auto-suspend    : 3 days idle
--   Cost            : billed only when workloads are running;
--                     one idle node is kept warm at Snowflake's cost.
CREATE STREAMLIT core.deals_app
  FROM '/streamlit'
  MAIN_FILE = 'streamlit_app.py'
  COMPUTE_POOL = SYSTEM_COMPUTE_POOL_CPU
  COMMENT = 'Native App Deals dashboard — demonstrates RCR inside a Snowflake Native App';

GRANT USAGE ON STREAMLIT core.deals_app TO APPLICATION ROLE APP_ADMIN;
GRANT USAGE ON STREAMLIT core.deals_app TO APPLICATION ROLE APP_USER;
