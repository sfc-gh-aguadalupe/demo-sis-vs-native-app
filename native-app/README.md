# Native App (SPCS) — Demo Walkthrough

This guide walks you through the Snowflake Native App Restricted Caller's Rights demo
using Snowpark Container Services (SPCS).

---

## What this demo shows

A Streamlit app packaged as a Docker container, deployed inside a Snowflake Native App
via SPCS, and installed in development mode in the same account. The app queries the
**consumer's own DEALS table** using Restricted Caller's Rights.

The key difference from the SiS standalone demo:

- The **provider** ships the app logic as a Docker image. They cannot access consumer data.
- The **consumer's admin** controls what data the app can read and which users
  the app can act on behalf of.
- Caller grants are configured by the consumer — not the provider.
- The app runs in a **consumer-created compute pool** (not `SYSTEM_COMPUTE_POOL_CPU`).

The app uses two connection patterns side by side:

| Connection | Token | Identity | Row Access Policy |
|---|---|---|---|
| Service OAuth token | `/snowflake/session/token` | App service identity | App role → all rows |
| Combined token (RCR) | Service token + `Sf-Context-Current-User-Token` header | Viewer | Viewer's default role → filtered |

---

## Prerequisites

| Requirement | Notes |
|---|---|
| Snowflake account | ACCOUNTADMIN access required |
| Snow CLI (`snow`) | Version >= 3.14.0 |
| Docker Desktop | For building and pushing the container image |
| RCR Preview enrolled | Available in all commercial regions and AWS gov regions |

---

## Setup steps

### Step 1 — Build and push the Docker image

From the `native-app/` directory:

```bash
# Build for linux/amd64 (required for SPCS)
docker build --platform linux/amd64 -t deals_streamlit:latest app/streamlit/

# Tag for the Snowflake registry
docker tag deals_streamlit:latest \
  <org>-<account>.registry.snowflakecomputing.com/sales_demo_pkg/app_src/img_repo/deals_streamlit:latest

# Log in to the registry
snow spcs image-registry login

# Push the image
docker push <org>-<account>.registry.snowflakecomputing.com/sales_demo_pkg/app_src/img_repo/deals_streamlit:latest
```

> **Note:** Replace `<org>-<account>` with your org-account identifier
> (e.g., `sfseeurope-uswest2demo`). The image repository
> `SALES_DEMO_PKG.APP_SRC.IMG_REPO` must exist before pushing
> (created automatically by `snow app run` on first deploy, or manually via
> `CREATE IMAGE REPOSITORY`).

### Step 2 — Deploy the app

```bash
cd native-app
snow app run
```

This command:
1. Creates the application package `SALES_DEMO_PKG`
2. Uploads `manifest.yml`, `setup_script.sql`, `service_spec.yaml` to the package stage
3. Installs `SALES_DEMO_APP` in development mode using `setup_script.sql`

### Step 3 — Create consumer data (`01_create_consumer_data.sql`)
Role: `ACCOUNTADMIN`

Creates `CONSUMER_DB.SALES.DEALS` with sample data, a Row Access Policy, demo
users (`ALICE_WEST`, `BOB_EAST`, `CAROL_EAST`, `SALES_MANAGER`), and a warehouse
`CONSUMER_WH`.

The Row Access Policy on the consumer's table:
- `CONSUMER_MANAGER_ROLE` → all rows
- Service identity (SPCS) → all rows
- Everyone else → only rows where `rep_name = CURRENT_USER()`

### Step 4 — Configure caller grants (`02_setup_caller_grants.sql`)
Roles: `ACCOUNTADMIN` then `SYSADMIN`

The consumer admin grants the app permission to access their table and warehouse
via caller rights:

```sql
GRANT MANAGE CALLER GRANTS ON ACCOUNT TO ROLE SYSADMIN;
GRANT CALLER USAGE ON DATABASE CONSUMER_DB TO APPLICATION SALES_DEMO_APP;
GRANT CALLER USAGE ON SCHEMA CONSUMER_DB.SALES TO APPLICATION SALES_DEMO_APP;
GRANT CALLER SELECT ON TABLE CONSUMER_DB.SALES.DEALS TO APPLICATION SALES_DEMO_APP;
GRANT CALLER USAGE ON WAREHOUSE CONSUMER_WH TO APPLICATION SALES_DEMO_APP;
```

### Step 5 — Grant privileges and start the service (`03_grant_to_app.sql`)
Role: `ACCOUNTADMIN`

Creates a compute pool, grants privileges to the app, and starts the SPCS service:

```sql
-- Create a compute pool dedicated to this app
CREATE COMPUTE POOL SALES_DEMO_POOL
  FOR APPLICATION SALES_DEMO_APP
  MIN_NODES = 1 MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_S
  AUTO_RESUME = TRUE AUTO_SUSPEND_SECS = 300;

-- Grant compute + network + data access
GRANT USAGE ON COMPUTE POOL SALES_DEMO_POOL TO APPLICATION SALES_DEMO_APP;
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO APPLICATION SALES_DEMO_APP;
GRANT USAGE ON DATABASE CONSUMER_DB TO APPLICATION SALES_DEMO_APP;
GRANT USAGE ON SCHEMA CONSUMER_DB.SALES TO APPLICATION SALES_DEMO_APP;
GRANT SELECT ON TABLE CONSUMER_DB.SALES.DEALS TO APPLICATION SALES_DEMO_APP;
GRANT USAGE ON WAREHOUSE CONSUMER_WH TO APPLICATION SALES_DEMO_APP;

-- Start the service
CALL SALES_DEMO_APP.core.start_app('SALES_DEMO_POOL', 'CONSUMER_WH');
```

### Step 6 — Grant users access to the app endpoint

```sql
GRANT APPLICATION ROLE SALES_DEMO_APP.APP_USER TO USER ALICE_WEST;
GRANT APPLICATION ROLE SALES_DEMO_APP.APP_USER TO USER BOB_EAST;
GRANT APPLICATION ROLE SALES_DEMO_APP.APP_USER TO USER CAROL_EAST;
GRANT APPLICATION ROLE SALES_DEMO_APP.APP_USER TO USER SALES_MANAGER;
```

### Step 7 — Get the endpoint URL

```sql
SHOW ENDPOINTS IN SERVICE SALES_DEMO_APP.core.deals_service;
```

The `ingress_url` column contains the public URL for the Streamlit app.

---

## Demo flow (live presentation)

1. Open the endpoint URL in a browser. Log in as `ALICE_WEST`.
   - Native app banner confirms "Running inside Native App (SPCS)"
   - Left panel: 6 deals (app's owner view — service identity)
   - Right panel: 2 deals — Alice's West region deals

2. Open an incognito window. Log in as `BOB_EAST`.
   - Right panel: 2 East region deals (Globex Corp + Initech)

3. Open another incognito window. Log in as `SALES_MANAGER`.
   - Right panel: all 6 deals (manager role passes through the RAP)

4. Key talking point:
   > "This is the same Streamlit code running inside an SPCS container.
   > The provider shipped the Docker image. The consumer's admin created
   > the compute pool, granted data access, and configured caller grants.
   > The provider never entered this account. In production this app could be
   > installed by 50 different customers — each one's admin controls what
   > data the app reads and who the app acts as."

---

## How SPCS RCR works

```
Browser Request → SPCS Ingress (public endpoint)
                    │
                    ├── Injects Sf-Context-Current-User-Token header (viewer identity)
                    │
                    └── Streamlit Container
                          │
                          ├── Owner connection:
                          │     token = /snowflake/session/token
                          │     → connects as service identity (DEALS_SERVICE)
                          │
                          └── RCR connection:
                                token = service_token + "." + caller_token
                                → connects as the VIEWER (e.g., ALICE_WEST)
                                → restricted by GRANT CALLER grants
```

The `executeAsCaller: true` setting in `service_spec.yaml` tells SPCS to inject the
caller token header. The manifest's `restricted_callers_rights: enabled: true` enables
the RCR framework for the app.

---

## Teardown

```bash
# Stop the service
CALL SALES_DEMO_APP.core.stop_app();

# Drop the app
snow app teardown   -- from native-app/ directory
```

Then in Snowflake (as ACCOUNTADMIN):
```sql
DROP COMPUTE POOL IF EXISTS SALES_DEMO_POOL;
DROP DATABASE IF EXISTS CONSUMER_DB;
DROP WAREHOUSE IF EXISTS CONSUMER_WH;
DROP USER IF EXISTS ALICE_WEST;
DROP USER IF EXISTS BOB_EAST;
DROP USER IF EXISTS CAROL_EAST;
DROP USER IF EXISTS SALES_MANAGER;
DROP ROLE IF EXISTS CONSUMER_REP_ROLE;
DROP ROLE IF EXISTS CONSUMER_MANAGER_ROLE;
```

---

## Architecture diagram

```
Snowflake Account (single account, dev-mode install)
│
├── CONSUMER_DB.SALES.DEALS  ──► Row Access Policy (deals_rap)
│                                  ↓ filters by CURRENT_USER() / CURRENT_ROLE()
│
├── SALES_DEMO_POOL  (CPU_X64_S, 1 node, FOR APPLICATION)
│
└── SALES_DEMO_APP  (Native App — installed from SALES_DEMO_PKG)
        Service: core.deals_service  →  SALES_DEMO_POOL
        Container: deals_streamlit:latest (port 8501)
        │
        ├── Owner connection (service OAuth token):
        │     → runs as DEALS_SERVICE / SALES_DEMO_APP role
        │     → RAP exemption for service identity → all rows
        │
        └── RCR connection (combined token):
              → runs as CURRENT VIEWER (e.g., ALICE_WEST)
              → restricted by GRANT CALLER grants
              → RAP filters by viewer's identity → viewer's rows only
```

---

## Files reference

| File | Purpose |
|---|---|
| `snowflake.yml` | Snow CLI project: defines package + app entities |
| `app/manifest.yml` | App metadata, container images, requested privileges, RCR config |
| `app/setup_script.sql` | Runs on install: creates roles, schema, start/stop procedures |
| `app/service_spec.yaml` | SPCS service spec: container, endpoint, executeAsCaller, serviceRoles |
| `app/streamlit/Dockerfile` | Docker image for the Streamlit container (python:3.11-slim) |
| `app/streamlit/streamlit_app.py` | Dual-connection RCR Streamlit (SPCS OAuth tokens) |
| `app/streamlit/requirements.txt` | Python dependencies (streamlit, snowflake-connector-python, pandas) |
| `consumer_setup/01_create_consumer_data.sql` | Consumer's DEALS table + RAP + users |
| `consumer_setup/02_setup_caller_grants.sql` | Consumer grants caller rights to app |
| `consumer_setup/03_grant_to_app.sql` | Consumer grants compute pool, data access, starts service |

---

## Snow CLI connection note

If the named connection in `~/.snowflake/connections.toml` fails with error `251007`
(session token invalid), use `--temporary-connection` with inline parameters:

```bash
snow app run --temporary-connection \
  --account <account> \
  --user <user> \
  --authenticator SNOWFLAKE_JWT \
  --private-key-path <path-to-key> \
  --role ACCOUNTADMIN \
  --warehouse compute_wh
```
