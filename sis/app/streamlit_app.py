"""
sis/app/streamlit_app.py
Restricted Caller's Rights Demo — Streamlit in Snowflake (Standalone)

This app opens TWO Snowflake connections in the same session:

  owner_conn  = st.connection("snowflake")
    → Runs every query as the APP OWNER (STREAMLIT_OWNER_ROLE).
      Row Access Policy sees the owner's role → pass-through → all rows.

  rcr_conn    = st.connection("snowflake-callers-rights")
    → Runs every query as the APP VIEWER (the person who opened the URL).
      Row Access Policy sees the VIEWER's role → filtered rows.

Side-by-side columns make the difference immediately visible:
  Left  panel  = owner's view  → always shows all 6 deals
  Right panel  = caller's view → shows only the viewer's own deals

Prerequisites (see sis/setup/):
  - Container runtime via SYSTEM_COMPUTE_POOL_CPU (no setup needed)
  - Caller grants configured in 04_setup_caller_grants.sql
  - Row Access Policy attached in 03_row_access_policy.sql
"""

import streamlit as st

st.set_page_config(
    page_title="RCR Demo — SiS Standalone",
    page_icon="🔐",
    layout="wide",
    initial_sidebar_state="collapsed",
)

# ─────────────────────────────────────────────────────────────────────────────
# IMPORTANT: Create BOTH connections at the TOP of the script (module level).
#
# The Restricted Caller's Rights token is issued at session start and is valid
# for only 2 minutes.  If you create st.connection("snowflake-callers-rights")
# inside an if/else block, a page function, or a button callback, the token
# may already be expired by the time the code runs, causing auth failures.
# ─────────────────────────────────────────────────────────────────────────────
owner_conn = st.connection("snowflake")                   # owner's rights
rcr_conn   = st.connection("snowflake-callers-rights")    # viewer's identity


# ── Helpers ──────────────────────────────────────────────────────────────────

def get_owner_context():
    return owner_conn.query(
        "SELECT CURRENT_USER() AS who, CURRENT_ROLE() AS role",
        ttl=0,
    )

def get_owner_deals():
    return owner_conn.query(
        """
        SELECT rep_name  AS "Rep",
               region    AS "Region",
               deal_name AS "Deal",
               amount    AS "Amount ($)"
        FROM   SALES_DB.SALES.DEALS
        ORDER  BY amount DESC
        """,
        ttl=0,
    )

# scope="session" is REQUIRED for Restricted Caller's Rights cache entries.
# Without it Streamlit's default global cache would mix data across viewers.
#
# IMPORTANT: use rcr_conn.cursor() instead of rcr_conn.query().
# conn.query() wraps results in its own @st.cache_data (without scope="session"),
# which Streamlit blocks when the connection is an RCR connection.
# Using the raw cursor bypasses that internal cache entirely.
@st.cache_data(scope="session")
def get_caller_context():
    import pandas as pd
    cur = rcr_conn.cursor()
    cur.execute("SELECT CURRENT_USER() AS who, CURRENT_ROLE() AS role")
    cols = [d[0] for d in cur.description]
    return pd.DataFrame(cur.fetchall(), columns=cols)

@st.cache_data(scope="session")
def get_caller_deals():
    import pandas as pd
    cur = rcr_conn.cursor()
    # CALLER USAGE grants permission to use DEMO_WH, but the RCR session
    # starts with no active warehouse — we must select it explicitly.
    cur.execute("USE WAREHOUSE DEMO_WH")
    cur.execute(
        """
        SELECT rep_name  AS "Rep",
               region    AS "Region",
               deal_name AS "Deal",
               amount    AS "Amount ($)"
        FROM   SALES_DB.SALES.DEALS
        ORDER  BY amount DESC
        """
    )
    cols = [d[0] for d in cur.description]
    return pd.DataFrame(cur.fetchall(), columns=cols)


# ── Page header ──────────────────────────────────────────────────────────────
st.title("🔐 Restricted Caller's Rights — SiS Standalone")
st.markdown(
    """
    The **same Streamlit app** opens two Snowflake connections.
    Only the right-hand connection "borrows" the viewer's identity.

    | Connection | Identity used | Row Access Policy applies as… |
    |---|---|---|
    | `st.connection("snowflake")` | App **owner** | Owner's role → sees **all rows** |
    | `st.connection("snowflake-callers-rights")` | App **viewer** | Viewer's default role → **filtered rows** |

    > **Try it:** open this URL logged in as `ALICE_WEST`, `BOB_EAST`, or `SALES_MANAGER`
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
        f"Role: `{ctx['ROLE'][0]}`"
    )

    df_owner = get_owner_deals()
    st.metric("Deals visible", len(df_owner), help="Owner's role is in the RAP pass-through list")
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
        f"Role: `{ctx_rcr['ROLE'][0]}`"
    )

    df_rcr = get_caller_deals()
    total  = 6  # total rows seeded
    st.metric(
        "Deals visible",
        len(df_rcr),
        delta=f"{len(df_rcr) - total} vs owner view",
        help="Viewer's default role is used; Row Access Policy filters rows",
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
            "Make sure the username matches a `rep_name` value in the DEALS table, "
            "or that the viewer holds `SALES_MANAGER_ROLE`."
        )


# ── Footer ────────────────────────────────────────────────────────────────────
st.divider()
st.caption(
    "SiS Standalone · Container runtime · `SYSTEM_COMPUTE_POOL_CPU` · "
    "RCR is a Preview feature (available in all commercial regions).  "
    "See [POSITIONING.md](../POSITIONING.md) for the full comparison with Native Apps."
)
