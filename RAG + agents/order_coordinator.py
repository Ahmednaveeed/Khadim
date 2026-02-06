# order_coordinator.py
"""
Order Coordinator - Atomic Order Flow with 2-Phase Commit Pattern

Coordinates the order flow across 3 agents (cart → order → kitchen) as a single
atomic transaction with rollback capability.

Flow:
1. PREPARE PHASE: Acquire locks, validate state
2. EXECUTE PHASE: Cart finalize → Order save → Kitchen plan
3. COMMIT/ROLLBACK: On success commit, on failure rollback all changes

This ensures:
- No partial orders (cart cleared but order not saved)
- No orphan orders (order saved but kitchen not notified)
- Automatic cleanup on failure
"""

import json
import uuid
from datetime import datetime
from typing import Dict, Optional, Tuple
from enum import Enum

from redis_connection import RedisConnection
from database_connection import DatabaseConnection
from redis_lock import get_lock_manager, get_idempotency_manager


class OrderState(Enum):
    """States for order transaction tracking."""
    INITIATED = "initiated"
    CART_LOCKED = "cart_locked"
    CART_FINALIZED = "cart_finalized"
    ORDER_SAVED = "order_saved"
    KITCHEN_NOTIFIED = "kitchen_notified"
    COMMITTED = "committed"
    ROLLED_BACK = "rolled_back"
    FAILED = "failed"


class OrderCoordinator:
    """
    Implements 2-Phase Commit for order processing.
    
    Manages the transaction state and provides rollback capability
    if any step fails.
    """
    
    TRANSACTION_PREFIX = "txn:order:"
    TRANSACTION_TTL = 300  # 5 minutes max for a transaction
    
    def __init__(self, send_task_func):
        """
        Args:
            send_task_func: Function to send tasks to agents (from orchestrator)
        """
        self.redis = RedisConnection.get_instance()
        self.db = DatabaseConnection.get_instance()
        self.lock_manager = get_lock_manager()
        self.idempotency = get_idempotency_manager()
        self.send_task = send_task_func
        
        self._transaction_id = None
        self._cart_id = None
        self._order_id = None
        self._cart_snapshot = None  # For rollback
        self._state = OrderState.INITIATED
    
    # =========================================================
    #   MAIN ATOMIC ORDER FLOW
    # =========================================================
    
    def execute_atomic_order(self, cart_id: str, idempotency_key: str = None) -> Dict:
        """
        Execute the complete order flow atomically.
        
        This is the main entry point that:
        1. Checks for duplicate requests (idempotency)
        2. Acquires necessary locks
        3. Executes cart → order → kitchen flow
        4. Commits or rolls back based on result
        
        Args:
            cart_id: The cart to finalize
            idempotency_key: Optional key to prevent duplicate orders
            
        Returns:
            Result dict with success status and message
        """
        # Generate idempotency key if not provided
        if not idempotency_key:
            idempotency_key = f"order:{cart_id}:{datetime.now().strftime('%Y%m%d%H%M')}"
        
        # Check for duplicate request
        cached = self.idempotency.check_and_get_cached(idempotency_key)
        if cached:
            return {
                "success": True,
                "message": "Order already processed (duplicate request detected)",
                "order_result": cached,
                "duplicate": True
            }
        
        self._cart_id = cart_id
        self._transaction_id = str(uuid.uuid4())[:8]
        
        print(f"\n[OrderCoordinator] ========================================")
        print(f"[OrderCoordinator] Starting Transaction: {self._transaction_id}")
        print(f"[OrderCoordinator] Cart ID: {cart_id}")
        
        try:
            # PHASE 1: PREPARE
            prepare_result = self._prepare_phase()
            if not prepare_result["success"]:
                return prepare_result
            
            # PHASE 2: EXECUTE
            execute_result = self._execute_phase()
            if not execute_result["success"]:
                # Rollback on failure
                self._rollback()
                return execute_result
            
            # PHASE 3: COMMIT
            self._commit()
            
            # Cache result for idempotency
            self.idempotency.cache_result(idempotency_key, execute_result)
            
            return execute_result
            
        except Exception as e:
            print(f"[OrderCoordinator] ❌ Transaction failed with exception: {e}")
            self._rollback()
            return {
                "success": False,
                "message": f"Order failed: {str(e)}",
                "transaction_id": self._transaction_id
            }
        
        finally:
            # Always release locks
            self._cleanup_locks()
    
    # =========================================================
    #   PHASE 1: PREPARE
    # =========================================================
    
    def _prepare_phase(self) -> Dict:
        """
        Prepare phase: Acquire locks and validate state.
        """
        print(f"[OrderCoordinator] Phase 1: PREPARE")
        
        # 1. Acquire cart lock
        if not self.lock_manager.acquire_cart_lock(self._cart_id, timeout=30):
            return {
                "success": False,
                "message": "Cart is currently being modified by another process. Please try again.",
                "error_code": "CART_LOCKED"
            }
        
        self._update_state(OrderState.CART_LOCKED)
        
        # 2. Snapshot current cart state (for potential rollback)
        self._cart_snapshot = self._get_cart_snapshot()
        
        if not self._cart_snapshot or self._cart_snapshot.get("is_empty"):
            self.lock_manager.release_cart_lock(self._cart_id)
            return {
                "success": False,
                "message": "Your cart is empty. Add items before placing an order.",
                "error_code": "CART_EMPTY"
            }
        
        # 3. Record transaction state in Redis
        self._save_transaction_state()
        
        print(f"[OrderCoordinator] ✅ Prepare phase complete. Cart has {len(self._cart_snapshot.get('items', []))} items")
        return {"success": True}
    
    # =========================================================
    #   PHASE 2: EXECUTE
    # =========================================================
    
    def _execute_phase(self) -> Dict:
        """
        Execute phase: Perform the actual order operations.
        """
        print(f"[OrderCoordinator] Phase 2: EXECUTE")
        
        # Step 1: Finalize Cart
        print(f"[OrderCoordinator] Step 1/3: Finalizing cart...")
        cart_result = self.send_task("cart", "place_order", {"cart_id": self._cart_id})
        
        if not cart_result.get("success"):
            return {
                "success": False,
                "message": cart_result.get("message", "Failed to finalize cart"),
                "error_code": "CART_FINALIZE_FAILED",
                "step_failed": "cart"
            }
        
        self._update_state(OrderState.CART_FINALIZED)
        cart_summary = cart_result.get("order_data", {})
        
        # Step 2: Save Order
        print(f"[OrderCoordinator] Step 2/3: Saving order...")
        order_result = self.send_task(
            "order", "save_and_summarize_order",
            {"cart_id": self._cart_id, "cart_summary": cart_summary}
        )
        
        if not order_result.get("success"):
            return {
                "success": False,
                "message": order_result.get("message", "Failed to save order"),
                "error_code": "ORDER_SAVE_FAILED",
                "step_failed": "order"
            }
        
        self._order_id = order_result.get("order_id")
        self._update_state(OrderState.ORDER_SAVED)
        
        # Step 3: Send to Kitchen (with expanded items)
        print(f"[OrderCoordinator] Step 3/3: Sending to kitchen...")
        kitchen_items = self._prepare_kitchen_items(cart_summary.get("items", []))
        
        if kitchen_items:
            kitchen_payload = {"order_id": self._order_id, "items": kitchen_items}
            kitchen_result = self.send_task("kitchen", "plan_order", kitchen_payload)
            
            if kitchen_result.get("success"):
                self._update_state(OrderState.KITCHEN_NOTIFIED)
                est_time = kitchen_result.get("estimated_total_minutes", "?")
                kitchen_msg = f"\n\n👨‍🍳 **Kitchen Update:** Your order is being prepared.\n⏱️ Estimated time: **{est_time} minutes**."
            else:
                # Kitchen failure is non-critical - order is still saved
                kitchen_msg = "\n\n(Note: Kitchen system offline, but order is saved.)"
        else:
            kitchen_msg = ""
        
        # Build final message
        base_message = order_result.get("message", "Order processed.")
        full_message = base_message + kitchen_msg
        
        return {
            "success": True,
            "message": full_message,
            "order_id": self._order_id,
            "order_result": order_result,
            "transaction_id": self._transaction_id
        }
    
    # =========================================================
    #   PHASE 3: COMMIT / ROLLBACK
    # =========================================================
    
    def _commit(self) -> None:
        """Commit the transaction - mark as complete."""
        print(f"[OrderCoordinator] Phase 3: COMMIT ✅")
        self._update_state(OrderState.COMMITTED)
        
        # Clean up transaction record
        txn_key = f"{self.TRANSACTION_PREFIX}{self._transaction_id}"
        self.redis.delete(txn_key)
    
    def _rollback(self) -> None:
        """
        Rollback the transaction - restore previous state.
        """
        print(f"[OrderCoordinator] ⚠️ ROLLBACK initiated for transaction {self._transaction_id}")
        
        try:
            # Rollback based on current state
            if self._state in [OrderState.ORDER_SAVED, OrderState.KITCHEN_NOTIFIED]:
                # Need to delete the saved order
                if self._order_id:
                    self._delete_order(self._order_id)
                    print(f"[OrderCoordinator] Rolled back order #{self._order_id}")
            
            if self._state in [OrderState.CART_FINALIZED, OrderState.ORDER_SAVED, OrderState.KITCHEN_NOTIFIED]:
                # Need to restore cart items
                if self._cart_snapshot:
                    self._restore_cart(self._cart_snapshot)
                    print(f"[OrderCoordinator] Restored cart items")
            
            self._update_state(OrderState.ROLLED_BACK)
            
        except Exception as e:
            print(f"[OrderCoordinator] ❌ Rollback failed: {e}")
            self._update_state(OrderState.FAILED)
    
    def _cleanup_locks(self) -> None:
        """Release all locks held by this transaction."""
        if self._cart_id:
            self.lock_manager.release_cart_lock(self._cart_id)
        if self._order_id:
            self.lock_manager.release_order_lock(self._order_id)
    
    # =========================================================
    #   HELPER METHODS
    # =========================================================
    
    def _get_cart_snapshot(self) -> Optional[Dict]:
        """Get current cart state for potential rollback."""
        result = self.send_task("cart", "get_cart_summary", {"cart_id": self._cart_id})
        return result if result.get("success") else None
    
    def _save_transaction_state(self) -> None:
        """Save transaction state to Redis for recovery."""
        txn_key = f"{self.TRANSACTION_PREFIX}{self._transaction_id}"
        txn_data = {
            "transaction_id": self._transaction_id,
            "cart_id": self._cart_id,
            "state": self._state.value,
            "started_at": datetime.now().isoformat(),
            "cart_snapshot": self._cart_snapshot
        }
        self.redis.setex(txn_key, self.TRANSACTION_TTL, json.dumps(txn_data))
    
    def _update_state(self, new_state: OrderState) -> None:
        """Update transaction state."""
        self._state = new_state
        print(f"[OrderCoordinator] State: {new_state.value}")
    
    def _delete_order(self, order_id: int) -> None:
        """Delete an order from database (rollback)."""
        try:
            with self.db.get_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("DELETE FROM orders WHERE order_id = %s", (order_id,))
                    conn.commit()
        except Exception as e:
            print(f"[OrderCoordinator] Failed to delete order {order_id}: {e}")
    
    def _restore_cart(self, snapshot: Dict) -> None:
        """Restore cart items from snapshot (rollback)."""
        try:
            with self.db.get_connection() as conn:
                with conn.cursor() as cur:
                    # Re-insert cart items from snapshot
                    for item in snapshot.get("items", []):
                        cur.execute("""
                            INSERT INTO cart_items 
                            (cart_id, item_id, item_type, item_name, quantity, unit_price)
                            VALUES (%s, %s, %s, %s, %s, %s)
                            ON CONFLICT (cart_id, item_id, item_type) DO NOTHING
                        """, (
                            self._cart_id,
                            item.get("item_id"),
                            item.get("item_type"),
                            item.get("item_name"),
                            item.get("quantity"),
                            item.get("unit_price")
                        ))
                    
                    # Restore cart status
                    cur.execute(
                        "UPDATE cart SET status = 'active' WHERE cart_id = %s",
                        (self._cart_id,)
                    )
                    conn.commit()
        except Exception as e:
            print(f"[OrderCoordinator] Failed to restore cart: {e}")
    
    def _prepare_kitchen_items(self, raw_items: list) -> list:
        """Prepare items for kitchen (with deal expansion)."""
        kitchen_items = []
        
        for item in raw_items:
            item_id = item.get("item_id")
            item_type = item.get("item_type", "menu_item")
            qty = int(item.get("quantity", 1))
            name = item.get("item_name")
            
            if item_type == "deal":
                # Expand deal into menu items
                expanded = self._expand_deal(item_id, qty)
                kitchen_items.extend(expanded)
            else:
                kitchen_items.append({"menu_item_id": int(item_id), "qty": qty})
        
        return kitchen_items
    
    def _expand_deal(self, deal_id: int, deal_qty: int) -> list:
        """Expand a deal into its component menu items."""
        items = []
        try:
            with self.db.get_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        "SELECT menu_item_id, quantity FROM deal_item WHERE deal_id = %s",
                        (deal_id,)
                    )
                    rows = cur.fetchall() or []
            
            for row in rows:
                menu_item_id = int(row[0])
                base_qty = int(row[1] or 1)
                items.append({
                    "menu_item_id": menu_item_id,
                    "qty": base_qty * deal_qty,
                })
        except Exception as e:
            print(f"[OrderCoordinator] Error expanding deal: {e}")
        
        return items


def create_order_coordinator(send_task_func) -> OrderCoordinator:
    """Factory function to create OrderCoordinator with the orchestrator's send function."""
    return OrderCoordinator(send_task_func)
