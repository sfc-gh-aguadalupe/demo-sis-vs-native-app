-- ============================================================
-- sis/setup/06_deploy_streamlit.sql
-- Uploads the app source files and creates the Streamlit object
-- using the container runtime and SYSTEM_COMPUTE_POOL_CPU.
--
-- SYSTEM_COMPUTE_POOL_CPU is a system-managed compute pool
-- available in every Snowflake account with no setup required.
-- It is the CPU pool that supports Streamlit apps, Notebooks,
-- and ML jobs.  It starts suspended and is billed only when in use.
--
-- Run as: STREAMLIT_OWNER_ROLE
-- ============================================================

USE ROLE STREAMLIT_OWNER_ROLE;
USE DATABASE SALES_DB;
USE SCHEMA SALES;

-- ── Stage for source files ────────────────────────────────────
CREATE STAGE IF NOT EXISTS SALES_DB.SALES.STREAMLIT_STAGE
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'Hosts source files for the SiS Deals RCR demo app';

-- ── Upload source files ───────────────────────────────────────
-- Run these PUT commands from SnowSQL (or use the Snowsight Files tab
-- on the stage) to upload the files in sis/app/ to the stage.
--
-- From your terminal (SnowSQL):
--   PUT file:///path/to/demo-sis-vs-native-app/sis/app/streamlit_app.py
--       @SALES_DB.SALES.STREAMLIT_STAGE/app/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
--   PUT file:///path/to/demo-sis-vs-native-app/sis/app/requirements.txt
--       @SALES_DB.SALES.STREAMLIT_STAGE/app/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- ── Create the Streamlit app ──────────────────────────────────
-- COMPUTE_POOL = SYSTEM_COMPUTE_POOL_CPU  →  no provisioning needed,
-- available in every Snowflake account.  The pool starts suspended
-- and wakes automatically when the first viewer opens the app.
-- NOTE: QUERY_WAREHOUSE is required even for container runtime — Snowflake uses
-- it for internal metadata queries.  Without it the app fails to load with
-- "No warehouse found for the Streamlit object."
-- RUNTIME_NAME must be set explicitly — without it the app silently falls
-- back to warehouse runtime and st.connection("snowflake-callers-rights") fails.
CREATE STREAMLIT IF NOT EXISTS SALES_DB.SALES.DEALS_APP
  FROM @SALES_DB.SALES.STREAMLIT_STAGE/app
  MAIN_FILE = 'streamlit_app.py'
  RUNTIME_NAME = 'SYSTEM$ST_CONTAINER_RUNTIME_PY3_11'
  COMPUTE_POOL = SYSTEM_COMPUTE_POOL_CPU
  QUERY_WAREHOUSE = DEMO_WH
  -- Uncomment the next line if you added packages to requirements.txt
  -- and ran 05_create_pypi_eai.sql:
  -- EXTERNAL_ACCESS_INTEGRATIONS = (PYPI_ACCESS_INTEGRATION)
  COMMENT = 'SiS standalone demo — Restricted Caller''s Rights on container runtime';

-- ── Share the app with demo users ────────────────────────────
GRANT USAGE ON STREAMLIT SALES_DB.SALES.DEALS_APP TO ROLE SALES_REP_ROLE;
GRANT USAGE ON STREAMLIT SALES_DB.SALES.DEALS_APP TO ROLE SALES_MANAGER_ROLE;

-- ── Get the app URL ───────────────────────────────────────────
-- After creation, retrieve the viewer URL from:
SHOW STREAMLITS IN SCHEMA SALES_DB.SALES;
