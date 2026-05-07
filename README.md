# SiS Standalone vs Native App — Demo Quickstart

This repo contains two end-to-end demos that show how **Restricted Caller's Rights (RCR)**
works in two distinct Snowflake deployment contexts:

| Demo | Path | What it shows |
|---|---|---|
| Streamlit in Snowflake (Standalone) | `sis/` | RCR in a single-account deployment |
| Streamlit inside a Native App (SPCS) | `native-app/` | RCR in a cross-account packaged app |

Both apps use the **same dual-connection Streamlit pattern** — one connection with
owner's rights (sees all data) and one with restricted caller's rights (sees only
the viewer's data). The security model difference is who controls the grants.

Read [POSITIONING.md](./POSITIONING.md) first to understand what each approach is,
why the security models differ, and how to use this repo in a customer presentation.

---

## Prerequisites

| Requirement | SiS Demo | Native App Demo |
|---|---|---|
| Snowflake account | Required | Required |
| ACCOUNTADMIN access | Required | Required |
| Snow CLI (`snow`) | Not needed | Required (>= 3.14.0) |
| Docker Desktop | Not needed | Required (for building container image) |
| RCR Preview enrolled | Required | Required |

RCR is available in all commercial regions and AWS government regions.

---

## Quickstart — SiS Standalone

```bash
# 1. Run setup scripts in order (Snowflake worksheet or SnowSQL)
sis/setup/01_create_data.sql          # as SYSADMIN
sis/setup/02_create_roles_users.sql   # as ACCOUNTADMIN
sis/setup/03_row_access_policy.sql    # as SYSADMIN
sis/setup/04_setup_caller_grants.sql  # as ACCOUNTADMIN then SYSADMIN
# 05 is optional — only needed if you add packages to requirements.txt
sis/setup/06_deploy_streamlit.sql     # as STREAMLIT_OWNER_ROLE
```

Open the Streamlit URL (from `SHOW STREAMLITS`) as `ALICE_WEST`, `BOB_EAST`, or
`SALES_MANAGER` to see RCR in action.

Full walkthrough: [sis/README.md](./sis/README.md)

---

## Quickstart — Native App (SPCS)

```bash
# 1. Build and push the Docker image
cd native-app
docker build --platform linux/amd64 -t deals_streamlit:latest app/streamlit/
docker tag deals_streamlit:latest \
  <org>-<account>.registry.snowflakecomputing.com/sales_demo_pkg/app_src/img_repo/deals_streamlit:latest
snow spcs image-registry login
docker push <org>-<account>.registry.snowflakecomputing.com/sales_demo_pkg/app_src/img_repo/deals_streamlit:latest

# 2. Deploy the app
snow app run

# 3. Run consumer setup scripts in order (Snowflake worksheet)
native-app/consumer_setup/01_create_consumer_data.sql  # as ACCOUNTADMIN
native-app/consumer_setup/02_setup_caller_grants.sql   # as ACCOUNTADMIN then SYSADMIN
native-app/consumer_setup/03_grant_to_app.sql          # as ACCOUNTADMIN

# 4. Grant app role to test users
GRANT APPLICATION ROLE SALES_DEMO_APP.APP_USER TO USER ALICE_WEST;

# 5. Get the endpoint URL
SHOW ENDPOINTS IN SERVICE SALES_DEMO_APP.core.deals_service;
```

Open the endpoint URL in a browser and log in as `ALICE_WEST`, `BOB_EAST`, or
`SALES_MANAGER` to see RCR in action.

Full walkthrough: [native-app/README.md](./native-app/README.md)

---

## Teardown

```sql
-- SiS demo
-- Run sis/setup/07_teardown.sql as ACCOUNTADMIN

-- Native App demo
CALL SALES_DEMO_APP.core.stop_app();  -- stop the SPCS service
-- Then from native-app/ directory:
snow app teardown
-- Then clean up consumer objects:
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

## Repo structure

```
demo-sis-vs-native-app/
├── POSITIONING.md                   ← Start here: positioning + demo narrative
├── README.md                        ← This file
├── shared/
│   └── sample_data.sql              ← Reusable seed INSERT statements
├── sis/
│   ├── README.md                    ← SiS step-by-step demo guide
│   ├── setup/                       ← SQL scripts 01–07
│   └── app/
│       ├── streamlit_app.py         ← Dual-connection Streamlit app
│       └── requirements.txt
└── native-app/
    ├── README.md                    ← Native App (SPCS) step-by-step guide
    ├── snowflake.yml                ← Snow CLI project file
    ├── .gitignore
    ├── app/
    │   ├── manifest.yml             ← App metadata + RCR config
    │   ├── setup_script.sql         ← Runs on install: roles, procedures
    │   ├── service_spec.yaml        ← SPCS spec: container, endpoint, executeAsCaller
    │   └── streamlit/
    │       ├── Dockerfile           ← Docker image (python:3.11-slim + streamlit)
    │       ├── streamlit_app.py     ← SPCS OAuth + RCR token pattern
    │       └── requirements.txt
    └── consumer_setup/              ← Scripts consumer admin runs post-install
        ├── 01_create_consumer_data.sql
        ├── 02_setup_caller_grants.sql
        └── 03_grant_to_app.sql
```
