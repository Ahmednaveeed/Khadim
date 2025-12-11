import os
import pandas as pd
from sqlalchemy import create_engine
from dotenv import load_dotenv
from database_connection import DatabaseConnection

# Load environment variables
load_dotenv()
db_url = os.getenv("DATABASE_URL")
engine = create_engine(db_url)
db_instance = DatabaseConnection.get_instance()

def format_menu_item(row):
    text = f"Menu Item: {row.item_name}"
    if pd.notna(row.item_description):
        text += f"\nDescription: {row.item_description}"
    if pd.notna(row.item_cuisine):
        text += f"\nCuisine: {row.item_cuisine}"
    if pd.notna(row.item_category):
        text += f"\nCategory: {row.item_category}"
    if pd.notna(row.item_price):
        text += f"\nPrice: {row.item_price}"
    if pd.notna(row.serving_size):
        text += f"\nServes: {row.serving_size} people"
    if pd.notna(row.quantity_description):
        text += f"\nPortion Quantity: {row.quantity_description}"
    if pd.notna(row.prep_time_minutes):
        text += f"\nPrep Time (MINUTES): {row.prep_time_minutes}"
    return text

def format_deal(row):
    text = f"Deal: {row.deal_name}"
    if pd.notna(row.deal_price):
        text += f"\nPrice: {row.deal_price}"
    if pd.notna(row.serving_size):
        text += f"\nServing Size: {row.serving_size}"
    if pd.notna(row.prep_time):
        text += f"\nPrep Time: Approximately {row.prep_time} minutes"
    if pd.notna(row['items']):
        text += f"\nIncludes: {row['items']}"
    return text

def load_texts():
    """
    Connects to the database, runs the menu and deal queries with all required fields,
    formats each row into a text block, and returns a combined list.
    """
    with engine.connect() as conn:
        menu_query = """
        SELECT
          mi.item_id,
          mi.item_name,
          mi.item_description,
          mi.item_cuisine,
          mi.item_category,
          mi.item_price,
          mi.serving_size,
          mi.quantity_description,
          mi.prep_time_minutes
        FROM menu_item mi
        ORDER BY mi.item_id;
        """
        
        deal_query = """
        SELECT
          d.deal_id,
          d.deal_name,
          d.deal_price,
          d.serving_size,
          MAX(mi.prep_time_minutes) AS prep_time,
          string_agg(
            di.quantity::text || ' ' || mi.item_name,
            ', ' ORDER BY di.menu_item_id
          ) AS items
        FROM deal d
        JOIN deal_item di ON di.deal_id = d.deal_id
        JOIN menu_item mi ON mi.item_id = di.menu_item_id
        GROUP BY d.deal_id, d.deal_name, d.deal_price, d.serving_size
        ORDER BY d.deal_id;
        """
        menu_df = pd.read_sql(menu_query, conn)
        deal_df = pd.read_sql(deal_query, conn)

    menu_texts = [format_menu_item(row) for _, row in menu_df.iterrows()]
    deal_texts = [format_deal(row) for _, row in deal_df.iterrows()]

    return menu_texts + deal_texts


class SearchAgent:
    """Simple Search Agent for matching menu items and deals"""
    def __init__(self):
        self.blocks = load_texts()
        self.db = DatabaseConnection.get_instance()
    
    def _get_real_item_id(self, item_name: str) -> int:
        """Get the actual database ID for a menu item by name."""
        try:
            with self.db.get_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT item_id FROM menu_item WHERE item_name ILIKE %s LIMIT 1", (item_name,))
                    row = cur.fetchone()
                    if row:
                        return row[0] if isinstance(row, tuple) else row['item_id']
        except Exception as e:
            print(f"[SearchAgent] Error fetching real ID for '{item_name}': {e}")
        return None
    
    def _get_real_deal_id(self, deal_name: str) -> int:
        """Get the actual database ID for a deal by name."""
        try:
            with self.db.get_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT deal_id FROM deal WHERE deal_name ILIKE %s LIMIT 1", (deal_name,))
                    row = cur.fetchone()
                    if row:
                        return row[0] if isinstance(row, tuple) else row['deal_id']
        except Exception as e:
            print(f"[SearchAgent] Error fetching real deal ID for '{deal_name}': {e}")
        return None

    def search(self, term: str):
        """Search for menu items or deals matching the given term"""
        term_lower = term.lower()
        hits = []
        for block in self.blocks:
            if term_lower in block.lower():
                lines = block.splitlines()
                entry = {"raw": block}
                
                # Initialize fields to ensure they exist
                entry["item_category"] = ""
                entry["item_cuisine"] = ""
                
                name_line = lines[0]
                
                # Extract Name & Type
                if "Menu Item:" in name_line:
                    entry["type"] = "menu_item"
                    entry["item_name"] = name_line.split(":", 1)[1].strip()
                    # Fetch REAL ID from database
                    real_id = self._get_real_item_id(entry["item_name"])
                    entry["item_id"] = real_id if real_id else None
                elif "Deal:" in name_line:
                    entry["type"] = "deal"
                    entry["item_name"] = name_line.split(":", 1)[1].strip()
                    # Fetch REAL ID from database
                    real_id = self._get_real_deal_id(entry["item_name"])
                    entry["deal_id"] = real_id if real_id else None

                price = 0.0
                
                # Parse the rest of the lines
                for ln in lines:
                    val = ""
                    if ":" in ln:
                        val = ln.split(":", 1)[1].strip()
                        
                    if ln.lower().startswith("price:"):
                        try:
                            price = float(val)
                        except:
                            pass
                    # --- ADDED PARSING LOGIC HERE ---
                    elif ln.lower().startswith("category:"):
                        entry["item_category"] = val
                    elif ln.lower().startswith("cuisine:"):
                        entry["item_cuisine"] = val
                
                entry["price"] = price
                hits.append(entry)
        return hits

    def get_context_blocks(self):
        """Get all text blocks as a single context string"""
        return "\n\n---\n\n".join(self.blocks)


if __name__ == "__main__":
    texts = load_texts()
    print("Loaded", len(texts), "text blocks.\n")
    agent = SearchAgent()
    print("Testing search for 'karahi'...")
    results = agent.search("karahi")
    if results:
        print(f"Found: {results[0]['item_name']}")
        print(f"Category: {results[0].get('item_category')}") # Should print 'main'
    else:
        print("Nothing found.")