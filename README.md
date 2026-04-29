# SiS Standalone vs Native App — Demo Quickstart

This repo contains two end-to-end demos that show how **Restricted Caller's Rights (RCR)**
works in two distinct Snowflake deployment contexts:

| Demo | Path | What it shows |
|---|---|---|
| Streamlit in Snowflake (Standalone) | `sis/` | RCR in a single-account deployment |
| Streamlit inside a Native App | `native-app/` | RCR in a cross-account packaged app |

Both apps use the **same dual-connection Streamlit pattern** and run on
`SYSTEM_COMPUTE_POOL_CPU` — the system-managed compute pool available in every
Snowflake account with no setup required.

Read [POSITIONING.md](./POSITIONING.md) first to understand what each approach is,
why the security models differ, and how to use this repo in a customer presentation.

---

## Prerequisites

| Requirement | SiS Demo | Native App Demo |
|---|---|---|
| Snowflake account | Required | Required |
| ACCOUNTADMIN access | Required | Required |
| Snow CLI (`snow`) | Not needed | Required (`>= 3.14.0`) |
| Two Snowflake accounts | Not needed | Not needed (dev-mode installs in same account) |
| RCR Preview enrolled | Required | Required |
| `SYSTEM_COMPUTE_POOL_CPU` | Available by default | Available by default |

RCR is available in all commercial regions and AWS government regions.
Verify your account is enrolled: run `SHOW PARAMETERS LIKE 'ENABLE_%CALLER%' IN ACCOUNT;`

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

## Quickstart — Native App

```bash
# 1. Install the app (from the native-app/ directory)
cd native-app
snow app run

# 2. Run consumer setup scripts in order
native-app/consumer_setup/01_create_consumer_data.sql  # as SYSADMIN
native-app/consumer_setup/02_setup_caller_grants.sql   # as ACCOUNTADMIN then SYSADMIN
native-app/consumer_setup/03_grant_to_app.sql          # as ACCOUNTADMIN

# 3. Open the app in Snowsight → Apps → SALES_DEMO_APP
```

Full walkthrough: [native-app/README.md](./native-app/README.md)

---

## Teardown

```sql
-- SiS demo
-- Run sis/setup/07_teardown.sql as ACCOUNTADMIN

-- Native App demo
snow app teardown   -- from native-app/ directory
-- Then run consumer_setup teardown steps manually (drop CONSUMER_DB, roles, users)
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
    ├── README.md                    ← Native App step-by-step demo guide
    ├── snowflake.yml                ← Snow CLI project file
    ├── app/
    │   ├── manifest.yml
    │   ├── setup_script.sql
    │   └── streamlit/
    │       ├── streamlit_app.py     ← Same pattern, native app context
    │       └── requirements.txt
    └── consumer_setup/              ← Scripts consumer admin runs post-install
        ├── 01_create_consumer_data.sql
        ├── 02_setup_caller_grants.sql
        └── 03_grant_to_app.sql
```
