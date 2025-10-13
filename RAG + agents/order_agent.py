# order_agent.py

from database_connection import DatabaseConnection
from typing import Dict
import json

class OrderAgent:
    """Handles final order processing, summary, and order history saving."""
    
    def __init__(self):
        self.db = DatabaseConnection.get_instance()
    
    def _calculate_total_prep_time(self, cart_summary: Dict) -> int:
        """
        Calculates a realistic prep time by finding the longest prep time
        among all items and deals in the cart.
        """
        max_prep_time = 0
        
        with self.db.get_connection() as conn:
            with conn.cursor() as cur:
                for item in cart_summary.get('items', []):
                    item_prep_time = 0
                    if item['item_type'] == 'menu_item':
                        # Fetch prep time for a single menu item
                        cur.execute(
                            "SELECT prep_time_minutes FROM menu_item WHERE item_id = %s",
                            (item['item_id'],)
                        )
                        result = cur.fetchone()
                        if result and result[0] is not None:
                            item_prep_time = result[0]
                            
                    elif item['item_type'] == 'deal':
                        # For a deal, find the max prep time among its component items
                        cur.execute("""
                            SELECT MAX(mi.prep_time_minutes) 
                            FROM deal_item di
                            JOIN menu_item mi ON di.menu_item_id = mi.item_id
                            WHERE di.deal_id = %s
                        """, (item['item_id'],))
                        result = cur.fetchone()
                        if result and result[0] is not None:
                            item_prep_time = result[0]
                    
                    # Update the overall max prep time for the order
                    if item_prep_time > max_prep_time:
                        max_prep_time = item_prep_time
                        
        return max_prep_time if max_prep_time > 0 else 15 # Default if no times found

    def save_and_summarize_order(self, cart_id: str, cart_summary: Dict) -> Dict:
        """
        Saves the final order to the 'orders' table and prepares a confirmation summary.
        """
        
        total_price = cart_summary['total_price']
        # Use the new dynamic calculation instead of a hard-coded value
        estimated_prep_time = self._calculate_total_prep_time(cart_summary)
        
        try:
            order_data_json = json.dumps(cart_summary)
            with self.db.get_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("""
                        INSERT INTO orders 
                        (cart_id, total_price, estimated_prep_time_minutes, order_data)
                        VALUES (%s, %s, %s, %s)
                        RETURNING order_id
                    """, (cart_id, total_price, estimated_prep_time, order_data_json))
                    
                    order_id = cur.fetchone()[0]
                    conn.commit()
            
            # Prepare a more detailed confirmation summary
            summary_message = (
                f"✅ Your order (ID: {order_id}) has been successfully placed!\n\n"
                f"**Total:** Rs. {total_price:.2f}\n\n"
                f"**Estimated waiting time:** Approximately {estimated_prep_time} minutes."
            )
            
            return {
                'success': True,
                'message': summary_message,
                'order_id': order_id,
                'prep_time': estimated_prep_time
            }

        except Exception as e:
            return {
                'success': False,
                'message': f"Order Confirmation Agent failed to save the order: {str(e)}",
                'order_id': None,
                'prep_time': None
            }