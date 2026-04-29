# Native App — Demo Walkthrough

This guide walks you through the Snowflake Native App Restricted Caller's Rights demo.

---

## What this demo shows

A Streamlit app packaged as a Snowflake Native App and installed in development mode
in the same account. The app queries the **consumer's own DEALS table** using
Restricted Caller's Rights.

The key difference from the SiS standalone demo:

- The **provider** ships the app logic. They cannot access consumer data.
- The **consumer's admin** controls what data the app can read and which users
  the app can act on behalf of.
- Caller grants are configured by the consumer — not the provider.

Same dual-connection layout as the SiS demo:

| Connection | Identity | Row Access Policy |
|---|---|---|
| `st.connection("snowflake")` | App itself | App role → all rows |
| `st.connection("snowflake-callers-rights")` | Viewer | Viewer's default role → filtered |

---

## Prerequisites

- Snow CLI version **3.14.0 or later** (`snow --version`)
- Active Snowflake connection configured in `~/.snowflake/config.toml`
- ACCOUNTADMIN access in the target account

---

## Setup steps

### Step 1 — Install the app

From the `native-app/` directory:

```bash
snow app run
```

This command:
1. Creates the application package `SALES_DEMO_PKG`
2. Uploads all files under `native-app/app/` to the package stage
3. Installs `SALES_DEMO_APP` in development mode using `setup_script.sql`
4. Creates the Streamlit `core.deals_app` with `COMPUTE_POOL = SYSTEM_COMPUTE_POOL_CPU`

Verify the app is installed:

```bash
snow app list
```

### Step 2 — Create consumer data (`01_create_consumer_data.sql`)
Role: `SYSADMIN`

Creates `CONSUMER_DB.SALES.DEALS` with sample data, a Row Access Policy, and demo
users (`ALICE_WEST`, `BOB_EAST`, `CAROL_EAST`, `SALES_MANAGER`).

The Row Access Policy on the consumer's table:
- `CONSUMER_MANAGER_ROLE` → all rows
- Everyone else → only rows where `rep_name = CURRENT_USER()`

### Step 3 — Configure caller grants (`02_setup_caller_grants.sql`)
Roles: `ACCOUNTADMIN` then `SYSADMIN`

This is the consumer-side equivalent of SiS setup step 04. The consumer admin
grants the app permission to access their table and warehouse via caller rights:

```sql
GRANT MANAGE CALLER GRANTS ON ACCOUNT TO ROLE SYSADMIN;
GRANT CALLER SELECT ON TABLE CONSUMER_DB.SALES.DEALS TO APPLICATION SALES_DEMO_APP;
GRANT CALLER USAGE ON WAREHOUSE CONSUMER_WH TO APPLICATION SALES_DEMO_APP;
```

**Key insight for the demo:** In the SiS standalone flow, the account admin ran
this for `STREAMLIT_OWNER_ROLE` — a role they own. Here, the consumer runs it
targeting `APPLICATION SALES_DEMO_APP` — an object the **provider** shipped.
The consumer decides when and whether to grant these rights. The provider's code
cannot override this decision.

### Step 4 — Grant data access to the app (`03_grant_to_app.sql`)
Role: `ACCOUNTADMIN`

Grants the application direct read access to the consumer's DEALS table. Both this
grant and the caller grants (step 3) are required:

```sql
GRANT USAGE ON DATABASE CONSUMER_DB TO APPLICATION SALES_DEMO_APP;
GRANT USAGE ON SCHEMA CONSUMER_DB.SALES TO APPLICATION SALES_DEMO_APP;
GRANT SELECT ON TABLE CONSUMER_DB.SALES.DEALS TO APPLICATION SALES_DEMO_APP;
```

---

## Demo flow (live presentation)

1. In Snowsight go to **Apps → SALES_DEMO_APP** and open the Streamlit.
   Log in as `ALICE_WEST`.
   - Native app banner confirms "Running inside Native App: SALES_DEMO_APP"
   - Left panel: 6 deals (app's owner view)
   - Right panel: 2 deals — Alice's West region deals

2. Switch to `BOB_EAST`:
   - Right panel: 2 East region deals (Globex Corp + Initech)

3. Switch to `SALES_MANAGER`:
   - Right panel: all 6 deals (manager role passes through the RAP)

4. Before running `03_grant_to_app.sql`, show the error the app gives when the
   consumer hasn't yet granted access — makes the before/after contrast clear.

5. Key talking point:
   > "This is the same Streamlit code as the standalone version. The difference
   > is who configured the security: here it was the consumer's admin. The provider
   > never entered this account. In a real deployment, this app could be installed
   > by 50 different customers — each one's admin controls what data the app reads
   > and who the app acts as."

---

## Teardown

```bash
# From the native-app/ directory
snow app teardown
```

Then in Snowflake (as ACCOUNTADMIN):
```sql
-- Consumer-side cleanup
DROP DATABASE  IF EXISTS CONSUMER_DB;
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
└── SALES_DEMO_APP  (Native App — installed from SALES_DEMO_PKG)
        Streamlit: core.deals_app
        Runtime: Container  →  SYSTEM_COMPUTE_POOL_CPU
        │
        ├── st.connection("snowflake")
        │     → runs as the APPLICATION (app's own identity)
        │     → consumer granted SELECT to APPLICATION  →  all rows
        │
        └── st.connection("snowflake-callers-rights")
              → runs as CURRENT VIEWER (e.g. ALICE_WEST)
              → consumer set CALLER SELECT on TABLE  →  filtered rows
              (consumer controls this grant — provider cannot override it)
```

---

## Files reference

| File | Purpose |
|---|---|
| `snowflake.yml` | Snow CLI project: defines package + app entities |
| `app/manifest.yml` | App metadata, default Streamlit, requested privileges |
| `app/setup_script.sql` | Runs on install: creates roles, schema, Streamlit |
| `app/streamlit/streamlit_app.py` | Dual-connection RCR Streamlit |
| `consumer_setup/01_create_consumer_data.sql` | Consumer's DEALS table + RAP + users |
| `consumer_setup/02_setup_caller_grants.sql` | Consumer grants caller rights to app |
| `consumer_setup/03_grant_to_app.sql` | Consumer grants SELECT on DEALS to app |
