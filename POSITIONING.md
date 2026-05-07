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

Both paths support **Restricted Caller's Rights (RCR)** to provide per-user data
filtering via Row Access Policies. The deployment models and authentication mechanisms
differ.

---

## Side-by-side comparison

| Dimension | SiS Standalone | Native App (SPCS) |
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
| **Compute pool** | `SYSTEM_COMPUTE_POOL_CPU` (system-managed) | Consumer-created pool (`CPU_X64_S`) |
| **Runtime** | Container runtime (managed by Snowflake) | SPCS container (Docker image) |
| **RCR mechanism** | `st.connection("snowflake-callers-rights")` | `executeAsCaller` + combined OAuth tokens |

---

## What Restricted Caller's Rights solves

### Without RCR

By default every Streamlit in Snowflake runs with the **owner's rights**. All
viewers execute queries under the app owner's role. A Row Access Policy attached
to the data table would see the **owner's** `CURRENT_USER()` and `CURRENT_ROLE()`
for every query — regardless of who is viewing the app. Every user sees the same
data.

### With RCR

In the SiS standalone demo, `st.connection("snowflake-callers-rights")` opens a
second connection that runs queries under the **viewer's** identity.

In the Native App (SPCS) demo, the container reads the `Sf-Context-Current-User-Token`
header (injected by SPCS ingress when `executeAsCaller: true` is set) and combines
it with the service's own OAuth token to create an RCR connection.

In both cases, the Row Access Policy sees the actual viewer's `CURRENT_USER()` and
`CURRENT_ROLE()`. Each sales rep sees only their own deals. The manager sees all deals.

Critically, this is **restricted** caller rights — not full caller rights. The
admin must explicitly declare which tables and warehouses the app is allowed to
access on the viewer's behalf using `GRANT CALLER SELECT` and `GRANT CALLER USAGE`.
The app cannot access any table or warehouse not covered by these grants, even if
the viewer has broader privileges in the account.

### The two connections — SiS Standalone

```python
# Built-in connection helpers
owner_conn = st.connection("snowflake")                   # owner's rights
rcr_conn   = st.connection("snowflake-callers-rights")    # viewer's identity
```

### The two connections — Native App (SPCS)

```python
# Service OAuth token (owner's rights)
def _get_owner_connection():
    token = open("/snowflake/session/token").read().strip()
    return snowflake.connector.connect(
        host=os.environ["SNOWFLAKE_HOST"],
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        token=token, authenticator="oauth",
    )

# Combined token (RCR — viewer's identity)
def _get_caller_connection():
    service_token = open("/snowflake/session/token").read().strip()
    caller_token = st.context.headers["Sf-Context-Current-User-Token"]
    combined = service_token + "." + caller_token
    return snowflake.connector.connect(
        host=os.environ["SNOWFLAKE_HOST"],
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        token=combined, authenticator="oauth",
    )
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

### Native App (SPCS)

```
Provider Account                    Consumer Account
──────────────────                  ──────────────────────────────────────────
Provider builds Docker   ──push──►  Image repository in app package
Provider runs snow app run ─────►  Consumer Admin installs app
                                     └─► Creates COMPUTE POOL (FOR APPLICATION)
                                     └─► GRANT USAGE ON COMPUTE POOL to app
                                     └─► GRANT BIND SERVICE ENDPOINT to app
                                     └─► GRANT MANAGE CALLER GRANTS TO ROLE SYSADMIN
                                     └─► GRANT CALLER SELECT ON TABLE deals
                                           TO APPLICATION SALES_DEMO_APP
                                     └─► GRANT CALLER USAGE ON WAREHOUSE consumer_wh
                                           TO APPLICATION SALES_DEMO_APP
                                     └─► GRANT SELECT ON TABLE deals
                                           TO APPLICATION SALES_DEMO_APP
                                     └─► CALL app.core.start_app(pool, wh)

                                   Consumer Viewer opens SPCS endpoint
                                     └─► SPCS injects Sf-Context-Current-User-Token
                                           → container builds combined token
                                           → query runs as the consumer viewer
                                           → Row Access Policy on consumer's table fires
                                           → rep sees own deals / manager sees all
```

**The critical difference:** In the Native App model the provider never enters the
consumer's account. The consumer admin decides when to enable each grant. Caller
grants can be revoked at any time by the consumer — the provider cannot re-enable
them. This is the foundation of the trust model for distributable apps.

---

## Compute pools

| | SiS Standalone | Native App (SPCS) |
|---|---|---|
| **Pool name** | `SYSTEM_COMPUTE_POOL_CPU` | Consumer-created (e.g., `SALES_DEMO_POOL`) |
| **Instance family** | `CPU_X64_S` | `CPU_X64_S` |
| **Who creates it?** | System-managed (always exists) | Consumer admin |
| **Setup required?** | None | `CREATE COMPUTE POOL ... FOR APPLICATION` |
| **Auto-suspend** | 3 days idle | Configurable (e.g., 300 seconds) |

For SiS standalone, `SYSTEM_COMPUTE_POOL_CPU` is available in every Snowflake
account with zero setup. You never run `CREATE COMPUTE POOL` for this pool.

For Native Apps with SPCS, the consumer must create a dedicated compute pool using
`FOR APPLICATION <app_name>`, which restricts the pool exclusively to that app.

---

## When to use each approach

### Choose SiS Standalone when…

- The app and data are in **the same Snowflake account**
- You are building for an **internal audience** (employees, analysts, ops teams)
- You want the fastest path to deployment — no Docker, no packaging, no versioning
- You control the RBAC in the account
- Container runtime Streamlit is sufficient (no custom system dependencies)

### Choose a Native App (SPCS) when…

- You need to **distribute the app to multiple customers or accounts**
- You are building a **commercial product** (Snowflake Marketplace or direct listing)
- You want **version control** over releases (patches, release channels, upgrade policies)
- The consumer's data must **stay in their account** — the provider never accesses it
- You need the **consumer to control** exactly what data the app reads
- You need custom Docker dependencies or multi-container services

---

## Limitations and gotchas for RCR

### Common to both approaches

| Limitation | Detail |
|---|---|
| Viewer's **default** role | RCR uses the viewer's default role, not the role they selected in Snowsight. |
| No secondary roles | Secondary roles are not supported with RCR connections. |
| Preview feature | RCR is in Preview. Available in all commercial regions and AWS government regions. |

### SiS Standalone specific

| Limitation | Detail |
|---|---|
| Container runtime only | RCR does not work in warehouse runtime. Container runtime required. |
| Session-scoped caching | Must use `@st.cache_data(scope="session")` for RCR data. Global cache leaks data. |
| Connect at script top level | Create the connection at module level. The RCR token is valid for ~2 minutes. |

### Native App (SPCS) specific

| Limitation | Detail |
|---|---|
| Docker image required | Must build and push a container image to the Snowflake registry. |
| Consumer creates compute pool | `SYSTEM_COMPUTE_POOL_CPU` is not available for Native App SPCS services. |
| Token refresh | The service token at `/snowflake/session/token` must be re-read periodically. |
| `executeAsCaller: true` in spec | Required in `service_spec.yaml` for SPCS to inject the caller token header. |

---

## When NOT to use RCR

- **All viewers should see the same data** → use owner's rights only. No RCR needed.
- **Full caller privileges** → use a stored procedure with `EXECUTE AS CALLER`.
- **Warehouse runtime only** (SiS) → implement user-level filtering using `CURRENT_USER()` in a view or stored procedure.

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
   - Build + push Docker image, run `snow app run`, run consumer setup scripts
   - Open the SPCS endpoint URL as `ALICE_WEST`:
     - Native app banner confirms the SPCS context
     - Same side-by-side layout, same behavior
   - Say: *"Same Streamlit code, now running in an SPCS container. The provider
     shipped a Docker image. The consumer's admin created the compute pool,
     granted data access, and configured caller grants. The provider never ran a
     query against this data. In production this app could be shipped to 50 customers —
     each one's admin makes their own decision about what to grant."*

4. Close with the positioning table: same RCR outcome, fundamentally different
   ownership, trust model, and deployment mechanism.
