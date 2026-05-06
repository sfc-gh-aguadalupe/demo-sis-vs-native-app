"""
native-app/app/streamlit/streamlit_app.py
Restricted Caller's Rights Demo — Streamlit inside a Snowflake Native App (SPCS)

This app runs as an SPCS service inside a Snowflake Native App. It demonstrates
the same dual-connection RCR pattern as the SiS standalone demo, but uses the
SPCS authentication mechanism:

  Owner connection:
    Uses the service OAuth token from /snowflake/session/token.
    This token represents the app's own identity (the application object).

  RCR (caller) connection:
    Uses the service OAuth token PLUS the caller's ingress token from the
    Sf-Context-Current-User-Token header. When both tokens are provided
    together, Snowflake executes queries as the calling user (restricted
    by caller grants configured by the consumer admin).

The dual-column layout makes the security model tangible:
  Left  panel  (owner's rights)  → always shows all 6 deals
  Right panel  (caller's rights) → shows only the viewer's own deals

Prerequisites (see native-app/consumer_setup/):
  - App installed: snow app run (from native-app/ directory)
  - Consumer created compute pool + granted to app
  - Called core.start_app('<pool>', '<wh>')
  - 01_create_consumer_data.sql  run by consumer
  - 02_setup_caller_grants.sql   run by consumer admin
  - 03_grant_to_app.sql          run by consumer admin
"""

import os
import streamlit as st
import pandas as pd
import snowflake.connector


st.set_page_config(
    page_title="RCR Demo — Native App (SPCS)",
    page_icon="📦",
    layout="wide",
    initial_sidebar_state="collapsed",
)

# ─────────────────────────────────────────────────────────────────────────────
# SPCS Authentication
# ─────────────────────────────────────────────────────────────────────────────

def _get_login_token() -> str:
    """Read the service OAuth token mounted by SPCS."""
    with open("/snowflake/session/token", "r") as f:
        return f.read().strip()


def _get_owner_connection():
    """Create a connection using the service's own identity (owner's rights)."""
    return snowflake.connector.connect(
        host=os.environ["SNOWFLAKE_HOST"],
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        token=_get_login_token(),
        authenticator="oauth",
        warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", ""),
    )


def _get_caller_connection():
    """
    Create an RCR connection using the caller's ingress token.

    When executeAsCaller is enabled in the service spec, SPCS injects
    the Sf-Context-Current-User-Token header on every ingress request.
    Concatenating it with the service token (separated by a dot) tells
    Snowflake to execute as the calling user, restricted by caller grants.
    """
    caller_token = st.context.headers.get("Sf-Context-Current-User-Token", "")
    if not caller_token:
        st.error(
            "No caller token found. Ensure `executeAsCaller: true` is set "
            "in the service spec and you are accessing the app via the public endpoint."
        )
        st.stop()

    # Combine service token + caller token for RCR
    combined_token = _get_login_token() + "." + caller_token

    return snowflake.connector.connect(
        host=os.environ["SNOWFLAKE_HOST"],
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        token=combined_token,
        authenticator="oauth",
        warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", ""),
    )


# Table the consumer granted to this app (see consumer_setup/03_grant_to_app.sql)
CONSUMER_DEALS_TABLE = "CONSUMER_DB.SALES.DEALS"


# ── Helpers ──────────────────────────────────────────────────────────────────

def get_owner_context():
    conn = _get_owner_connection()
    cur = conn.cursor()
    cur.execute("SELECT CURRENT_USER() AS who, CURRENT_ROLE() AS role, CURRENT_DATABASE() AS db")
    cols = [d[0] for d in cur.description]
    df = pd.DataFrame(cur.fetchall(), columns=cols)
    cur.close()
    conn.close()
    return df


def get_owner_deals():
    conn = _get_owner_connection()
    cur = conn.cursor()
    cur.execute(f"""
        SELECT rep_name  AS "Rep",
               region    AS "Region",
               deal_name AS "Deal",
               amount    AS "Amount ($)"
        FROM   {CONSUMER_DEALS_TABLE}
        ORDER  BY amount DESC
    """)
    cols = [d[0] for d in cur.description]
    df = pd.DataFrame(cur.fetchall(), columns=cols)
    cur.close()
    conn.close()
    return df


@st.cache_data(scope="session")
def get_caller_context():
    conn = _get_caller_connection()
    cur = conn.cursor()
    cur.execute("USE WAREHOUSE CONSUMER_WH")
    cur.execute("SELECT CURRENT_USER() AS who, CURRENT_ROLE() AS role, CURRENT_DATABASE() AS db")
    cols = [d[0] for d in cur.description]
    df = pd.DataFrame(cur.fetchall(), columns=cols)
    cur.close()
    conn.close()
    return df


@st.cache_data(scope="session")
def get_caller_deals():
    conn = _get_caller_connection()
    cur = conn.cursor()
    cur.execute("USE WAREHOUSE CONSUMER_WH")
    cur.execute(f"""
        SELECT rep_name  AS "Rep",
               region    AS "Region",
               deal_name AS "Deal",
               amount    AS "Amount ($)"
        FROM   {CONSUMER_DEALS_TABLE}
        ORDER  BY amount DESC
    """)
    cols = [d[0] for d in cur.description]
    df = pd.DataFrame(cur.fetchall(), columns=cols)
    cur.close()
    conn.close()
    return df


# ── Native App banner ─────────────────────────────────────────────────────────
st.info(
    "📦 Running inside **Native App** (SPCS)  \n"
    "The provider shipped this app — the consumer installed it, "
    "created a compute pool, granted data access, and configured caller grants. "
    "The provider never accessed this account."
)

# ── Page header ───────────────────────────────────────────────────────────────
st.title("🔐 Restricted Caller's Rights — Native App")
st.markdown(
    f"""
    Querying consumer table: `{CONSUMER_DEALS_TABLE}`

    | Connection | Identity used | Row Access Policy applies as… |
    |---|---|---|
    | Service token (owner) | App **service identity** | App's role → sees **all rows** |
    | Combined token (RCR)  | App **viewer** | Viewer's default role → **filtered rows** |

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
    st.caption("Service OAuth token (app's own identity)")

    ctx = get_owner_context()
    st.info(
        f"Running as **{ctx['WHO'][0]}**  \n"
        f"Role: `{ctx['ROLE'][0]}`  \n"
        f"DB context: `{ctx['DB'][0]}`"
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
    st.caption("Combined token (service + caller ingress token)")

    ctx_rcr = get_caller_context()
    st.info(
        f"Running as **{ctx_rcr['WHO'][0]}**  \n"
        f"Role: `{ctx_rcr['ROLE'][0]}`  \n"
        f"DB context: `{ctx_rcr['DB'][0]}`"
    )

    df_rcr = get_caller_deals()
    total = 6
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
    "Native App · SPCS container · `CPU_X64_S` compute pool · "
    "RCR via `executeAsCaller` · "
    "See POSITIONING.md for the full comparison with SiS Standalone."
)

