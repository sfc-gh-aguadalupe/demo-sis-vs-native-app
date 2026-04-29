"""
native-app/app/streamlit/streamlit_app.py
Restricted Caller's Rights Demo — Streamlit inside a Snowflake Native App

This app is structurally identical to the SiS standalone version
(sis/app/streamlit_app.py) — same dual-connection pattern, same
two-column layout.  The differences are:

  1. CONTEXT  This Streamlit runs INSIDE a Snowflake Native App.
              CURRENT_DATABASE() returns the app name, not CONSUMER_DB.
              The consumer installed this app; the provider never touches
              their account or data.

  2. DATA     The app queries CONSUMER_DB.SALES.DEALS — a table in the
              CONSUMER's own account that the consumer granted to the app.

  3. CALLER   Caller grants are configured by the CONSUMER's admin
  GRANTS      (consumer_setup/02_setup_caller_grants.sql), not the provider.
              The consumer controls which of their tables and warehouses
              the app can access via caller rights.

The dual-connection pattern makes the security model tangible:
  Left  panel  (owner's rights)  → always shows all 6 deals
  Right panel  (caller's rights) → shows only the viewer's own deals

Prerequisites (see native-app/consumer_setup/):
  - App installed: snow app run (from native-app/ directory)
  - 01_create_consumer_data.sql  run by consumer
  - 02_setup_caller_grants.sql   run by consumer admin
  - 03_grant_to_app.sql          run by consumer admin
"""

import streamlit as st

st.set_page_config(
    page_title="RCR Demo — Native App",
    page_icon="📦",
    layout="wide",
    initial_sidebar_state="collapsed",
)

# ─────────────────────────────────────────────────────────────────────────────
# IMPORTANT: Create BOTH connections at the TOP of the script (module level).
# See sis/app/streamlit_app.py for a full explanation of why.
# ─────────────────────────────────────────────────────────────────────────────
owner_conn = st.connection("snowflake")                   # app's owner rights
rcr_conn   = st.connection("snowflake-callers-rights")    # viewer's identity

# Table the consumer granted to this app (see consumer_setup/03_grant_to_app.sql)
CONSUMER_DEALS_TABLE = "CONSUMER_DB.SALES.DEALS"


# ── Helpers ──────────────────────────────────────────────────────────────────

def get_owner_context():
    return owner_conn.query(
        "SELECT CURRENT_USER() AS who, CURRENT_ROLE() AS role, "
        "       CURRENT_DATABASE() AS db",
        ttl=0,
    )

def get_owner_deals():
    return owner_conn.query(
        f"""
        SELECT rep_name  AS "Rep",
               region    AS "Region",
               deal_name AS "Deal",
               amount    AS "Amount ($)"
        FROM   {CONSUMER_DEALS_TABLE}
        ORDER  BY amount DESC
        """,
        ttl=0,
    )

@st.cache_data(scope="session")   # scope="session" required for RCR
def get_caller_context():
    # Must use raw cursor — rcr_conn.query() wraps with @st.cache_data
    # internally (no scope="session"), which Streamlit blocks for RCR.
    import pandas as pd
    cur = rcr_conn.cursor()
    cur.execute(
        "SELECT CURRENT_USER() AS who, CURRENT_ROLE() AS role, "
        "       CURRENT_DATABASE() AS db"
    )
    cols = [d[0] for d in cur.description]
    return pd.DataFrame(cur.fetchall(), columns=cols)

@st.cache_data(scope="session")
def get_caller_deals():
    import pandas as pd
    cur = rcr_conn.cursor()
    cur.execute(f"""
        SELECT rep_name  AS "Rep",
               region    AS "Region",
               deal_name AS "Deal",
               amount    AS "Amount ($)"
        FROM   {CONSUMER_DEALS_TABLE}
        ORDER  BY amount DESC
    """)
    cols = [d[0] for d in cur.description]
    return pd.DataFrame(cur.fetchall(), columns=cols)


# ── Native App banner ─────────────────────────────────────────────────────────
app_ctx = owner_conn.query(
    "SELECT CURRENT_DATABASE() AS app_name", ttl=0
)
st.info(
    f"📦 Running inside Native App: **{app_ctx['APP_NAME'][0]}**  \n"
    "The provider shipped this app — the consumer installed it, "
    "granted data access, and configured caller grants.  "
    "The provider never accessed this account."
)

# ── Page header ───────────────────────────────────────────────────────────────
st.title("🔐 Restricted Caller's Rights — Native App")
st.markdown(
    f"""
    Querying consumer table: `{CONSUMER_DEALS_TABLE}`

    | Connection | Identity used | Row Access Policy applies as… |
    |---|---|---|
    | `st.connection("snowflake")` | App **owner** | App's role → sees **all rows** |
    | `st.connection("snowflake-callers-rights")` | App **viewer** | Viewer's default role → **filtered rows** |

    > **Try it:** open this app as `ALICE_WEST`, `BOB_EAST`, or `SALES_MANAGER`
    > and watch the right panel change while the left stays the same.
    """
)
st.divider()


# ── Two-column layout ────────────────────────────────────────────────────────
col_owner, col_rcr = st.columns(2, gap="large")


# ── Left: Owner's rights ─────────────────────────────────────────────────────
with col_owner:
    st.subheader("Owner's Rights")
    st.caption("`st.connection('snowflake')`")

    ctx = get_owner_context()
    st.info(
        f"Running as **{ctx['WHO'][0]}**  \n"
        f"Role: `{ctx['ROLE'][0]}`  \n"
        f"DB context: `{ctx['DB'][0]}`  ← app name, not consumer DB"
    )

    df_owner = get_owner_deals()
    st.metric("Deals visible", len(df_owner), help="App role sees all rows")
    st.dataframe(df_owner, use_container_width=True, hide_index=True)

    if not df_owner.empty:
        st.bar_chart(
            df_owner.set_index("Deal")["Amount ($)"],
            use_container_width=True,
        )


# ── Right: Restricted Caller's Rights ────────────────────────────────────────
with col_rcr:
    st.subheader("Restricted Caller's Rights")
    st.caption("`st.connection('snowflake-callers-rights')`")

    ctx_rcr = get_caller_context()
    st.info(
        f"Running as **{ctx_rcr['WHO'][0]}**  \n"
        f"Role: `{ctx_rcr['ROLE'][0]}`  \n"
        f"DB context: `{ctx_rcr['DB'][0]}`  ← viewer's context"
    )

    df_rcr = get_caller_deals()
    total  = 6
    st.metric(
        "Deals visible",
        len(df_rcr),
        delta=f"{len(df_rcr) - total} vs owner view",
        help="Viewer's default role used; Row Access Policy filters rows",
    )
    st.dataframe(df_rcr, use_container_width=True, hide_index=True)

    if not df_rcr.empty:
        st.bar_chart(
            df_rcr.set_index("Deal")["Amount ($)"],
            use_container_width=True,
        )
    elif len(df_rcr) == 0:
        st.warning(
            "No deals found for this viewer.  "
            "Ensure the Snowflake username matches a `rep_name` in the DEALS table, "
            "or that the viewer holds `CONSUMER_MANAGER_ROLE`."
        )


# ── Footer ────────────────────────────────────────────────────────────────────
st.divider()
st.caption(
    "Native App · Container runtime · `SYSTEM_COMPUTE_POOL_CPU` · "
    "RCR is a Preview feature (available in all commercial regions).  "
    "See [POSITIONING.md](../../POSITIONING.md) for the full comparison with SiS Standalone."
)
