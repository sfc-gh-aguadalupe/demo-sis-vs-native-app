# SiS Standalone — Demo Walkthrough

This guide walks you through the Streamlit in Snowflake (standalone) Restricted
Caller's Rights demo step by step.

---

## What this demo shows

A Streamlit app deployed directly in a Snowflake account that connects to Snowflake
**twice in the same session** — once with owner's rights and once with Restricted
Caller's Rights — and displays the results side by side.

The sales `DEALS` table has a Row Access Policy attached. The same table query
returns different rows depending on which connection is used:

- **Left panel** — `st.connection("snowflake")` runs as the app owner → policy pass-through → all 6 deals
- **Right panel** — `st.connection("snowflake-callers-rights")` runs as the viewer → policy filters rows

---

## Setup steps

Run each script in order. Each file has a comment at the top specifying which role
to use.

### Step 1 — Create data (`01_create_data.sql`)
Role: `SYSADMIN`

Creates `SALES_DB.SALES.DEALS` and seeds it with 6 deals across 3 reps and 2 regions.

### Step 2 — Roles & users (`02_create_roles_users.sql`)
Role: `ACCOUNTADMIN`

Creates:
- `STREAMLIT_OWNER_ROLE` — owns the Streamlit object
- `SALES_REP_ROLE` — assigned to individual reps (sees only own rows)
- `SALES_MANAGER_ROLE` — assigned to managers (sees all rows)
- Users: `ALICE_WEST`, `BOB_EAST`, `CAROL_EAST`, `SALES_MANAGER`
- Warehouse: `DEMO_WH`

### Step 3 — Row Access Policy (`03_row_access_policy.sql`)
Role: `SYSADMIN`

Creates and attaches a Row Access Policy to `DEALS`:
- `SALES_MANAGER_ROLE` or `STREAMLIT_OWNER_ROLE` → all rows
- Any other role → only rows where `rep_name = CURRENT_USER()`

### Step 4 — Caller grants (`04_setup_caller_grants.sql`)
Roles: `ACCOUNTADMIN` then `SYSADMIN`

This is the step that enables RCR. Without it the callers-rights connection will
fail with an authorization error.

```sql
GRANT MANAGE CALLER GRANTS ON ACCOUNT TO ROLE SYSADMIN;
GRANT CALLER SELECT ON TABLE SALES_DB.SALES.DEALS TO ROLE STREAMLIT_OWNER_ROLE;
GRANT CALLER USAGE ON WAREHOUSE DEMO_WH TO ROLE STREAMLIT_OWNER_ROLE;
```

**What this means:** Streamlit apps owned by `STREAMLIT_OWNER_ROLE` are *allowed*
to query `DEALS` and use `DEMO_WH` on behalf of the viewer. Snowflake enforces
that no other tables or warehouses can be accessed via caller rights.

### Step 5 — PyPI EAI (`05_create_pypi_eai.sql`) — OPTIONAL
Role: `ACCOUNTADMIN`

Only needed if you extend the app with packages from PyPI (e.g. `plotly`).
The demo app uses only packages bundled with the container runtime, so skip this
unless you add packages to `requirements.txt`.

### Step 6 — Deploy the Streamlit (`06_deploy_streamlit.sql`)
Role: `STREAMLIT_OWNER_ROLE`

1. Creates a stage `STREAMLIT_STAGE` in `SALES_DB.SALES`
2. Uploads `streamlit_app.py` and `requirements.txt` to the stage
3. Creates the Streamlit with `COMPUTE_POOL = SYSTEM_COMPUTE_POOL_CPU`

```sql
CREATE STREAMLIT SALES_DB.SALES.DEALS_APP
  FROM @STREAMLIT_STAGE/app
  MAIN_FILE = 'streamlit_app.py'
  COMPUTE_POOL = SYSTEM_COMPUTE_POOL_CPU;
```

After running, execute `SHOW STREAMLITS IN SCHEMA SALES_DB.SALES;` and copy the
viewer URL.

---

## Demo flow (live presentation)

1. Open the viewer URL in a browser. Log in as `ALICE_WEST`.
   - Left panel: 6 deals (owner's view)
   - Right panel: 2 deals — Acme Corp + Widget Inc (Alice's West region deals)
   - Both `CURRENT_USER()` values are shown; right panel shows `ALICE_WEST`

2. Open a new private/incognito window. Log in as `BOB_EAST`.
   - Right panel: 2 deals — Globex Corp + Initech

3. Open another window. Log in as `SALES_MANAGER`.
   - Right panel: all 6 deals (manager role passes through the RAP)

4. Key talking point:
   > "The app code is identical for every viewer. The Row Access Policy fires
   > using the viewer's identity — not the app owner's — because of Restricted
   > Caller's Rights. The left panel shows what would happen without RCR:
   > everyone would see the same owner-level data."

---

## Teardown

Run `sis/setup/07_teardown.sql` as `ACCOUNTADMIN`.

---

## Architecture diagram

```
Snowflake Account
│
├── SALES_DB.SALES.DEALS  ──► Row Access Policy (deals_rap)
│                                 ↓ filters by CURRENT_USER() / CURRENT_ROLE()
│
└── SALES_DB.SALES.DEALS_APP  (Streamlit)
        Owner: STREAMLIT_OWNER_ROLE
        Runtime: Container  →  SYSTEM_COMPUTE_POOL_CPU
        │
        ├── st.connection("snowflake")
        │     → runs as STREAMLIT_OWNER_ROLE
        │     → RAP pass-through  →  ALL 6 rows
        │
        └── st.connection("snowflake-callers-rights")
              → runs as CURRENT VIEWER (e.g. ALICE_WEST)
              → RAP filters  →  viewer's rows only
              (enabled by GRANT CALLER SELECT)
```
