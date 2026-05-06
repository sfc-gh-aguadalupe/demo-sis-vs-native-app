-- ============================================================
-- native-app/app/setup_script.sql
-- Runs automatically when a consumer installs or upgrades the app.
-- Creates application roles, the core schema, and a procedure
-- to start the SPCS service that hosts the Streamlit dashboard.
--
-- After installation the consumer must:
--   1. Create a compute pool (FOR APPLICATION SALES_DEMO_APP)
--   2. Grant BIND SERVICE ENDPOINT + USAGE ON COMPUTE POOL to the app
--   3. Call core.start_app('<pool_name>', '<warehouse_name>')
--   4. Run the scripts in consumer_setup/ for data + caller grants
-- ============================================================

-- ── Application roles ─────────────────────────────────────────
CREATE APPLICATION ROLE IF NOT EXISTS APP_ADMIN;
CREATE APPLICATION ROLE IF NOT EXISTS APP_USER;

-- ── Core schema ───────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS core;
GRANT USAGE ON SCHEMA core TO APPLICATION ROLE APP_ADMIN;
GRANT USAGE ON SCHEMA core TO APPLICATION ROLE APP_USER;

-- ── Start the SPCS service ────────────────────────────────────
-- The consumer calls this procedure after granting the compute pool
-- and BIND SERVICE ENDPOINT privileges to the application.
CREATE OR REPLACE PROCEDURE core.start_app(pool_name VARCHAR, wh_name VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS $$
BEGIN
    CREATE SERVICE IF NOT EXISTS core.deals_service
        IN COMPUTE POOL IDENTIFIER(:pool_name)
        FROM SPECIFICATION_FILE = '/service_spec.yaml'
        QUERY_WAREHOUSE = :wh_name;

    -- Grant the service role to application roles so users can access the endpoint
    GRANT SERVICE ROLE core.deals_service!app_user_role TO APPLICATION ROLE APP_ADMIN;
    GRANT SERVICE ROLE core.deals_service!app_user_role TO APPLICATION ROLE APP_USER;

    RETURN 'Service started. Run core.app_url() to get the endpoint URL.';
END;
$$;

GRANT USAGE ON PROCEDURE core.start_app(VARCHAR, VARCHAR) TO APPLICATION ROLE APP_ADMIN;

-- ── Get the app URL ───────────────────────────────────────────
CREATE OR REPLACE PROCEDURE core.app_url()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS $$
DECLARE
    url VARCHAR;
BEGIN
    CALL SYSTEM$GET_SERVICE_STATUS('core.deals_service');
    SELECT SYSTEM$GET_SERVICE_ENDPOINT('core.deals_service', 'ui') INTO :url;
    RETURN url;
END;
$$;

GRANT USAGE ON PROCEDURE core.app_url() TO APPLICATION ROLE APP_ADMIN;
GRANT USAGE ON PROCEDURE core.app_url() TO APPLICATION ROLE APP_USER;

-- ── Stop the service (cleanup) ────────────────────────────────
CREATE OR REPLACE PROCEDURE core.stop_app()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS $$
BEGIN
    DROP SERVICE IF EXISTS core.deals_service;
    RETURN 'Service stopped.';
END;
$$;

GRANT USAGE ON PROCEDURE core.stop_app() TO APPLICATION ROLE APP_ADMIN;
