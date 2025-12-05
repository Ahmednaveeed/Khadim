import streamlit as st
import time
import pandas as pd
import redis
import json
import uuid
import os
from dotenv import load_dotenv
from database_connection import DatabaseConnection
import psycopg2.extras

load_dotenv()

# --- CONFIG ---
st.set_page_config(page_title="👨‍🍳 Kitchen Dashboard", page_icon="🔥", layout="wide")

# Redis Config
REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
AGENT_TASKS_CHANNEL = "agent_tasks"
RESPONSE_CHANNEL_PREFIX = "agent_response_"

# Status Colors & Labels
STATUS_CONFIG = {
    "QUEUED":      {"color": "🔴", "label": "QUEUED"},
    "IN_PROGRESS": {"color": "🟠", "label": "COOKING"},
    "READY":       {"color": "🟢", "label": "READY TO SERVE"},
    "COMPLETED":   {"color": "🏁", "label": "DONE"}
}

# --- HELPERS ---

def get_redis_client():
    return redis.StrictRedis(host=REDIS_HOST, port=REDIS_PORT, db=0, decode_responses=True)

def send_update_command(task_id, new_status):
    """Sends a command to the Kitchen Agent via Redis to update status."""
    try:
        r = get_redis_client()
        response_channel = f"{RESPONSE_CHANNEL_PREFIX}{uuid.uuid4()}"
        
        payload = {
            "agent": "kitchen",
            "command": "update_status",
            "payload": {
                "task_id": task_id,
                "new_status": new_status
            },
            "response_channel": response_channel
        }
        
        r.publish(AGENT_TASKS_CHANNEL, json.dumps(payload))
        st.toast(f"Task {task_id} updated to {new_status}!", icon="👨‍🍳")
        
        # Small delay to allow DB to update before reload
        time.sleep(0.5) 
        st.rerun()
    except Exception as e:
        st.error(f"Failed to update task: {e}")

def fetch_active_tasks():
    """Fetches all tasks that are NOT completed."""
    db = DatabaseConnection.get_instance()
    sql = """
        SELECT * FROM kitchen_tasks 
        WHERE status != 'COMPLETED' 
        ORDER BY order_id ASC, created_at ASC
    """
    try:
        with db.get_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(sql)
                return cur.fetchall()
    except Exception as e:
        st.error(f"Database Error: {e}")
        return []

# --- MAIN UI ---

st.title("👨‍🍳 Kitchen Display System (KDS)")

# 1. SIDEBAR CONTROLS
with st.sidebar:
    st.header("Controls")
    refresh_rate = st.slider("Auto-Refresh Rate (seconds)", 5, 60, 15)
    
    if st.button("🔄 Force Refresh Now", use_container_width=True):
        st.rerun()
    
    st.divider()
    st.caption("Status Legend:")
    st.markdown("🔴 **Queued**: New Order")
    st.markdown("🟠 **Cooking**: Chef working")
    st.markdown("🟢 **Ready**: Waiter can take")

# 2. FETCH DATA
tasks = fetch_active_tasks()

if not tasks:
    st.success("🎉 All caught up! No active orders.")
else:
    # Group tasks by Order ID
    df = pd.DataFrame(tasks)
    orders = df.groupby("order_id")

    # 3. GRID LAYOUT (Max 3 orders per row)
    COLS_PER_ROW = 3
    order_groups = [list(orders)[i:i + COLS_PER_ROW] for i in range(0, len(orders), COLS_PER_ROW)]

    for group in order_groups:
        cols = st.columns(COLS_PER_ROW)
        
        for idx, (order_id, order_items) in enumerate(group):
            with cols[idx]:
                # CARD CONTAINER
                with st.container(border=True):
                    # Header
                    c_head1, c_head2 = st.columns([2, 1])
                    c_head1.subheader(f"🆔 #{order_id}")
                    c_head2.caption(f"{len(order_items)} Items")
                    st.divider()

                    # ITEMS LIST
                    for _, item in order_items.iterrows():
                        task_id = item['task_id']
                        status = item['status']
                        item_name = item['item_name']
                        chef = item['assigned_chef']
                        qty = item['qty']
                        
                        # Get Style info
                        style = STATUS_CONFIG.get(status, STATUS_CONFIG["QUEUED"])
                        
                        # Item Row
                        st.markdown(f"**{qty}x {item_name}**")
                        st.caption(f"👨‍🍳 {chef} | {style['color']} {style['label']}")
                        
                        # BIG ACTION BUTTONS
                        if status == "QUEUED":
                            if st.button("🔥 Start Cooking", key=f"btn_cook_{task_id}", type="primary", use_container_width=True):
                                send_update_command(task_id, "IN_PROGRESS")
                        
                        elif status == "IN_PROGRESS":
                            if st.button("✅ Mark Ready", key=f"btn_ready_{task_id}", use_container_width=True):
                                send_update_command(task_id, "READY")
                                
                        elif status == "READY":
                            if st.button("🏁 Complete", key=f"btn_done_{task_id}", use_container_width=True):
                                send_update_command(task_id, "COMPLETED")
                        
                        st.markdown("---")


# 4. NON-BLOCKING AUTO REFRESH LOGIC
# This puts a small text at the bottom right instead of freezing the script
if refresh_rate:
    time.sleep(1) # Small sleep to prevent tight loops, but not blocking interactions
    st.empty() # Placeholder
    
    # We use a trick: only rerun if enough time passed, 
    # but Streamlit runs top-to-bottom. 
    # The 'st_autorefresh' library is better, but to keep it pure python:
    
    if "last_refresh" not in st.session_state:
        st.session_state.last_refresh = time.time()

    if time.time() - st.session_state.last_refresh > refresh_rate:
        st.session_state.last_refresh = time.time()
        st.rerun()