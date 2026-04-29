# Positioning: SiS Standalone vs Streamlit in a Native App

This document is the **customer-facing narrative** for the demo in this repository.
Use it as a presenter guide and leave a copy in the repo for customers to read.

---

## The setup question

> "You want to show users a personalized data view — each user sees only their own
> records. What should you build and how should you secure it?"

There are two primary paths in Snowflake:

1. **Streamlit in Snowflake (Standalone)** — deploy directly in an account
2. **Streamlit inside a Snowflake Native App** — package and distribute to consumers

Both paths support **Restricted Caller's Rights (RCR)** and both require
**container runtime** on `SYSTEM_COMPUTE_POOL_CPU`. The security models are
fundamentally different.

---

## Side-by-side comparison

| Dimension | SiS Standalone | Native App |
|---|---|---|
| **Where does data live?** | Same Snowflake account | Consumer's own account |
| **Who deploys the app?** | Data team within the account | Provider ships to N consumers |
| **Who controls data access?** | Account admin (same account) | Consumer admin (after install) |
| **Who configures caller grants?** | Same account admin | Consumer admin |
| **Can you version / release the app?** | No | Yes (patches, release channels) |
| **App distribution** | Single account only | Marketplace or direct listing |
| **Security perimeter** | Account-level RBAC | App boundary + consumer grants |
| **Row Access Policy fires as…** | Viewer's identity (via RCR) | Viewer's identity (via RCR) |
| **Best for** | Internal tools, single-org apps | ISV products, cross-account sharing |
| **Compute pool** | `SYSTEM_COMPUTE_POOL_CPU` | `SYSTEM_COMPUTE_POOL_CPU` |
| **Streamlit code** | Identical pattern | Identical pattern |

---

## What Restricted Caller's Rights solves

### Without RCR

By default every Streamlit in Snowflake runs with the **owner's rights**. All
viewers execute queries under the app owner's role. A Row Access Policy attached
to the data table would see the **owner's** `CURRENT_USER()` and `CURRENT_ROLE()`
for every query — regardless of who is viewing the app. Every user sees the same
data.

### With RCR

`st.connection("snowflake-callers-rights")` opens a second connection that runs
queries under the **viewer's** identity. The Row Access Policy now sees the actual
viewer's `CURRENT_USER()` and `CURRENT_ROLE()`. Each sales rep sees only their own
deals. The manager sees all deals. The app code is the same for every viewer.

Critically, this is **restricted** caller rights — not full caller rights. The
admin must explicitly declare which tables and warehouses the app is allowed to
access on the viewer's behalf using `GRANT CALLER SELECT` and `GRANT CALLER USAGE`.
The app cannot access any table or warehouse not covered by these grants, even if
the viewer has broader privileges in the account.

### The two connections in one app

```python
# Both created at the TOP of the script (token expires in 2 minutes)
owner_conn = st.connection("snowflake")                   # owner's rights
rcr_conn   = st.connection("snowflake-callers-rights")    # viewer's identity

# owner_conn → same result for every viewer
# rcr_conn   → filtered result per viewer (RAP applies with viewer's role)
```

---

## How the RCR setup flows differ

### SiS Standalone

```
Same Account
─────────────────────────────────────────────────────
Account Admin
  └─► GRANT MANAGE CALLER GRANTS ON ACCOUNT TO ROLE SYSADMIN

Sysadmin
  └─► GRANT CALLER SELECT ON TABLE deals TO ROLE streamlit_owner_role
  └─► GRANT CALLER USAGE ON WAREHOUSE demo_wh TO ROLE streamlit_owner_role

Viewer opens Streamlit
  └─► st.connection("snowflake-callers-rights")
        → query runs as the viewer
        → Row Access Policy fires with viewer's CURRENT_USER()
        → rep sees own deals / manager sees all
```

### Native App

```
Provider Account                    Consumer Account
──────────────────                  ──────────────────────────────────────────
Provider builds app  ──install──►  Consumer Admin
                                     └─► Approves BIND SERVICE ENDPOINT
                                     └─► GRANT MANAGE CALLER GRANTS TO ROLE SYSADMIN
                                     └─► GRANT CALLER SELECT ON TABLE deals
                                           TO APPLICATION SALES_DEMO_APP
                                     └─► GRANT CALLER USAGE ON WAREHOUSE consumer_wh
                                           TO APPLICATION SALES_DEMO_APP
                                     └─► GRANT SELECT ON TABLE deals
                                           TO APPLICATION SALES_DEMO_APP

                                   Consumer Viewer opens Streamlit
                                     └─► st.connection("snowflake-callers-rights")
                                           → query runs as the consumer viewer
                                           → Row Access Policy on consumer's table fires
                                           → rep sees own deals / manager sees all
```

**The critical difference:** In the Native App model the provider never enters the
consumer's account. The consumer admin decides when to enable each grant. Caller
grants can be revoked at any time by the consumer — the provider cannot re-enable
them. This is the foundation of the trust model for distributable apps.

---

## The system compute pool

Both demos reference `COMPUTE_POOL = SYSTEM_COMPUTE_POOL_CPU` in their `CREATE STREAMLIT`
statements. This pool is available in every Snowflake account with zero setup.

| Property | Value |
|---|---|
| Pool name | `SYSTEM_COMPUTE_POOL_CPU` |
| Instance family | `CPU_X64_S` |
| Default max nodes | 150 |
| Auto-suspend | 3 days idle |
| Initial state | Suspended (wakes on first workload) |
| Idle node | Snowflake keeps 1 warm node at no cost for fast cold starts |
| Supported workloads | Streamlit apps, Notebooks, ML jobs |

You never run `CREATE COMPUTE POOL` for this pool. The only privilege you may need
is `GRANT USAGE ON COMPUTE_POOL SYSTEM_COMPUTE_POOL_CPU TO ROLE <role>` if you are
deploying a standalone SiS app as a non-admin role.

For the Native App, `SYSTEM_COMPUTE_POOL_CPU` is referenced directly in the
`setup_script.sql`. When the app installs in a consumer account, that consumer's
instance of the pool is used automatically.

---

## When to use each approach

### Choose SiS Standalone when…

- The app and data are in **the same Snowflake account**
- You are building for an **internal audience** (employees, analysts, ops teams)
- You want the fastest path to deployment — no packaging, no versioning required
- You control the RBAC in the account

### Choose a Native App when…

- You need to **distribute the app to multiple customers or accounts**
- You are building a **commercial product** (Snowflake Marketplace or direct listing)
- You want **version control** over releases (patches, release channels, upgrade policies)
- The consumer's data must **stay in their account** — the provider never accesses it
- You need the **consumer to control** exactly what data the app reads

---

## Limitations and gotchas for RCR

These apply to both deployment contexts.

| Limitation | Detail |
|---|---|
| Container runtime only | RCR does not work in warehouse runtime. Container runtime required. |
| Viewer's **default** role | `st.connection("snowflake-callers-rights")` uses the viewer's default role, not the role they selected in Snowsight. |
| Session-scoped caching | Must use `@st.cache_data(scope="session")` for any data fetched via the callers-rights connection. Global cache would leak data between sessions. |
| Connect at script top level | Create the connection at module level, never inside an `if/else`, button callback, or page function. The RCR token is valid for **2 minutes** from session start. |
| No secondary roles | Secondary roles are not supported with RCR connections. |
| Preview feature | RCR is in Preview. Available in all commercial regions and AWS government regions. |

---

## When NOT to use RCR

- **All viewers should see the same data** → use `st.connection("snowflake")` (default owner's rights). No RCR needed.
- **Full caller privileges** → use a stored procedure with `EXECUTE AS CALLER` called from the Streamlit.
- **Warehouse runtime only** → implement user-level filtering using `CURRENT_USER()` in a view or stored procedure called by the warehouse-runtime app.

---

## Demo presenter script

1. Open `POSITIONING.md` (this file). Walk the comparison table. Explain when
   to pick each.

2. **SiS demo:**
   - Run scripts `01` → `04` → `06` (skip 05 unless you add packages)
   - Open the Streamlit as `ALICE_WEST`:
     - Left panel: 6 deals. Right panel: 2 deals.
     - Point to `CURRENT_USER()` in each panel — left shows owner, right shows ALICE_WEST
   - Switch to `SALES_MANAGER`:
     - Right panel: all 6 deals (manager role passes through the RAP)
   - Say: *"Same URL, same code, different user — different data in the right panel."*

3. **Native App demo:**
   - Run `snow app run`
   - Run consumer setup scripts `01` → `02` → `03`
   - Open the app as `ALICE_WEST`:
     - Native app banner confirms the app context
     - Same side-by-side layout, same behavior
   - Say: *"Same Streamlit code. But now it's installed in the 'consumer' account.
     The provider never ran a query against this data. The consumer's admin decided
     to grant access. In production this app could be shipped to 50 customers —
     each one's admin makes their own decision about what to grant."*

4. Close with the positioning table: same RCR pattern, fundamentally different
   ownership and trust model.
