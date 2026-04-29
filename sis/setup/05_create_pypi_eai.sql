-- ============================================================
-- sis/setup/05_create_pypi_eai.sql
-- OPTIONAL — only required if your Streamlit app installs
-- packages from PyPI (e.g. plotly, scipy, etc.).
--
-- Container-runtime Streamlit apps install dependencies from
-- an external package index.  Snowflake provides a managed
-- network rule (SNOWFLAKE.EXTERNAL_ACCESS.PYPI_RULE) so you
-- don't need to define your own rule.
--
-- The demo app in sis/app/ uses only packages bundled with the
-- container runtime (streamlit, snowflake-snowpark-python) so
-- this EAI is not strictly needed for the demo.  Include it if
-- you extend the app with additional packages.
--
-- Run as: ACCOUNTADMIN
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ── Create the External Access Integration ───────────────────
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION PYPI_ACCESS_INTEGRATION
  ALLOWED_NETWORK_RULES = (SNOWFLAKE.EXTERNAL_ACCESS.PYPI_RULE)
  ENABLED = TRUE
  COMMENT = 'Allows container-runtime Streamlit apps to install packages from PyPI';

-- ── Grant USAGE to the Streamlit owner role ──────────────────
GRANT USAGE ON INTEGRATION PYPI_ACCESS_INTEGRATION
  TO ROLE STREAMLIT_OWNER_ROLE;

-- To use this EAI, add it to the CREATE STREAMLIT statement in
-- 06_deploy_streamlit.sql:
--   EXTERNAL_ACCESS_INTEGRATIONS = (PYPI_ACCESS_INTEGRATION)
-- and list the packages you need in sis/app/requirements.txt.
