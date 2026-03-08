# main.py

import os
from auth.auth_routes import router as auth_router
from fastapi import FastAPI, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional, Any

from voice.transcribe import transcribe_audio
from chat.chat_agent import get_ai_response
from dotenv import load_dotenv
from sqlalchemy import text


from cart.cart_routes import router as cart_router
from orders.order_routes import router as order_router
from agents.upsell_agent import UpsellAgent
from agents.recommender_agent import RecommendationEngine
from auth.auth_routes import get_current_user
from fastapi import Depends
from typing import Dict, List

from infrastructure.db import SQL_ENGINE

upsell_agent = UpsellAgent()
recommendation_engine = RecommendationEngine()

print("DB URL = ", os.getenv("DATABASE_URL"))


# Initialize AI agent


app = FastAPI()

app.include_router(auth_router)
app.include_router(cart_router)
app.include_router(order_router)


# CORS for Flutter
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def format_items_urdu(menu_items, deals):
    response_parts = []

    # MENU ITEMS
    if menu_items:
        for item in menu_items:
            response_parts.append(
                f"جی بالکل! {item['item_name']} دستیاب ہے۔\n"
                f"{item['item_description']}۔\n"
                f"ایک پلیٹ تقریباً {item['serving_size']} افراد کیلئے کافی ہوتی ہے۔\n"
                f"قیمت Rs {item['item_price']} ہے۔\n"
            )

    # DEALS
    if deals:
        for deal in deals:
            response_parts.append(
                f"ہمارا شاندار پیکج {deal['deal_name']} بھی موجود ہے۔\n"
                f"اس میں شامل ہیں: {deal['items']}۔\n"
                f"یہ پیکج {deal['serving_size']} افراد کیلئے بہترین ہے۔\n"
                f"کل قیمت Rs {deal['deal_price']} ہے۔\n"
                f"کیا آپ اس ڈیل کو آرڈر میں شامل کرنا چاہیں گے؟\n"
            )

    if not menu_items and not deals:
        return "معذرت، اس نام سے کوئی ڈش یا ڈیل موجود نہیں ہے۔"

    return "\n".join(response_parts)


@app.on_event("startup")
def warmup_whisper():
    print("Warming up Whisper model...")
    try:
        from voice.transcribe import transcribe_audio

        base_dir = os.path.dirname(os.path.abspath(__file__))   # backend/
        project_root = os.path.dirname(base_dir)                # project root
        audio_path = os.path.join(project_root, "voice", "empty.wav")

        if not os.path.exists(audio_path):
            print("Whisper warm-up skipped: empty.wav not found at:", audio_path)
            return

        transcribe_audio(audio_path)
        print("Whisper warm-up complete!")

    except Exception as e:
        print("Whisper warm-up failed:", e)

@app.get("/offers")
def get_offers():
    query = text("""
        SELECT offer_id, title, description, offer_code, validity, category
        FROM offers
        WHERE validity >= CURRENT_DATE
        ORDER BY validity ASC;
    """)

    with SQL_ENGINE.connect() as conn:
        rows = conn.execute(query).mappings().all()

    # Convert RowMapping -> dict for JSON
    return [dict(r) for r in rows]


@app.get("/menu")
def get_full_menu():
    query = text("""
       SELECT 
    item_id,
    item_name,
    item_description,
    item_category,
    item_cuisine,
    item_price,
    quantity_description,
    image_url
FROM menu_item
ORDER BY item_id;


    """)
    with SQL_ENGINE.connect() as conn:
        rows = conn.execute(query).mappings().all()

    return {"menu": list(rows)}


def fetch_menu_items_by_name(name: str):
    query = text("""
        SELECT 
            item_id,
            item_name,
            item_description,
            item_category,
            item_cuisine,
            item_price,
            serving_size,
            quantity_description,
            prep_time_minutes,
            image_url
        FROM menu_item
        WHERE 
            item_name ILIKE :name
            OR item_category ILIKE :name
            OR item_cuisine ILIKE :name
        ORDER BY item_id
        LIMIT 20;
    """)

    with SQL_ENGINE.connect() as conn:
        rows = conn.execute(query, {"name": f"%{name}%"}).mappings().all()

    return [dict(r) for r in rows]


def fetch_deals_by_name(name: str):
    query = text("""
        SELECT 
            d.deal_id, 
            d.deal_name, 
            d.deal_price, 
            d.serving_size,
            d.image_url,
            string_agg(
                di.quantity::text || ' ' || mi.item_name,
                ', ' ORDER BY mi.item_id
            ) AS items
        FROM deal d
        JOIN deal_item di ON di.deal_id = d.deal_id
        JOIN menu_item mi ON mi.item_id = di.menu_item_id
        WHERE 
            d.deal_name ILIKE :name
            OR mi.item_name ILIKE :name
            OR mi.item_category ILIKE :name
            OR mi.item_cuisine ILIKE :name
        GROUP BY 
            d.deal_id, 
            d.deal_name, 
            d.deal_price, 
            d.serving_size,
            d.image_url
        ORDER BY d.deal_id
        LIMIT 20;
    """)

    with SQL_ENGINE.connect() as conn:
        rows = conn.execute(query, {"name": f"%{name}%"}).mappings().all()

    return [dict(r) for r in rows]


# ------------------------------
# TEXT CHAT ENDPOINT
# ------------------------------

def format_results_response(menu_items, deals, language: str = "ur") -> str:
    """
    Build a user-facing reply strictly from database results.
    No hallucinations – only uses fields from menu_items and deals.
    """
    if not menu_items and not deals:
        if language == "en":
            return "Sorry, we could not find anything matching your request in our menu."
        return "معاف کیجیے، آپ کی درخواست کے مطابق ہمارے مینو میں کچھ نہیں ملا۔"

    lines = []

    # Menu items section
    if menu_items:
        if language == "en":
            lines.append("These items are available:")
        else:
            lines.append("یہ آئٹمز دستیاب ہیں:")

        for item in menu_items[:6]:  # limit to top 6
            name = item.get("item_name", "")
            desc = item.get("item_description", "") or ""
            price = item.get("item_price", 0)
            qty   = item.get("quantity_description", "") or ""
            cuisine = item.get("item_cuisine", "")
            category = item.get("item_category", "")

            if language == "en":
                line = f"- {name} – {desc} ({cuisine}, {category}) – Rs {price} ({qty})"
            else:
                line = f"- {name} – {desc} ({cuisine}, {category}) – قیمت: Rs {price} ({qty})"
            lines.append(line)

    # Deals section
    if deals:
        lines.append("")  # blank line

        if language == "en":
            lines.append("These deals are available:")
        else:
            lines.append("یہ ڈیلز دستیاب ہیں:")

        for deal in deals[:6]:
            name = deal.get("deal_name", "")
            items = deal.get("items", "") or ""
            price = deal.get("deal_price", 0)
            serving = deal.get("serving_size", 0)

            if language == "en":
                line = f"- {name} – {items} – Rs {price} (serves {serving} person)"
            else:
                line = f"- {name} – {items} – قیمت: Rs {price} (تقریباً {serving} افراد کیلئے)"
            lines.append(line)

    return "\n".join(lines)


# ------------------------------
# TEXT CHAT ENDPOINT
# ------------------------------

class TextChatRequest(BaseModel):
    session_id: Optional[str] = None
    message: str
    language: str = "ur"   # "ur" or "en"


@app.post("/chat")
async def chat_text_endpoint(req: TextChatRequest):
    user_text = req.message.strip()

    if not user_text:
        return {"success": False, "reply": "پیغام خالی ہے", "raw": {}}

    # 1) Let LLM decide TOOL_CALLS (intent + query)
    ai_response = get_ai_response(
        user_input=user_text,
        conversation_history=[],
        menu_context=""
    )

    tool_calls = getattr(ai_response, "tool_calls", [])

    menu_items = []
    deals = []
    used_search_tool = False

    # 2) Execute DB searches based on TOOL_CALLs
    for call in tool_calls:
        if call["name"] == "search_menu":
            used_search_tool = True
            query = call["args"].get("query", "")
            menu_items = fetch_menu_items_by_name(query)
            deals = fetch_deals_by_name(query)

    # 3) Decide final reply text
    if used_search_tool:
        # Ignore model free-text and build reply ONLY from DB results
        reply_text = format_results_response(menu_items, deals, language=req.language)
    else:
        # No search requested – just use the model's original reply (small talk etc.)
        reply_text = ai_response.content if hasattr(ai_response, "content") else str(ai_response)

    urdu_reply = format_items_urdu(menu_items, deals) if (menu_items or deals) else reply_text

    return {
       "success": True,
       "reply": urdu_reply,
       "menu_items": menu_items,
       "deals": deals,
       "raw": reply_text
    }



# ------------------------------
# VOICE CHAT ENDPOINT
# ------------------------------

# ------------------------------
# VOICE CHAT ENDPOINT
# ------------------------------
@app.post("/voice_chat")
async def chat_voice_endpoint(
    session_id: str = Form(...),
    language: str = Form("ur"),
    file: UploadFile = File(...)
):
    os.makedirs("temp_voice", exist_ok=True)
    audio_path = f"temp_voice/{file.filename}"

    with open(audio_path, "wb") as f:
        f.write(await file.read())

    # 1) Transcribe audio
    transcript = transcribe_audio(audio_path)

    # 2) Get AI tool-call response
    ai_response = get_ai_response(
        user_input=transcript,
        conversation_history=[],
        menu_context=""
    )

    tool_calls = getattr(ai_response, "tool_calls", [])

    menu_items = []
    deals = []
    used_search_tool = False

    # 3) Execute tool calls (search)
    for call in tool_calls:
        if call["name"] == "search_menu":
            used_search_tool = True
            query = call["args"].get("query", "")
            menu_items = fetch_menu_items_by_name(query)
            deals = fetch_deals_by_name(query)

    # 4) Format reply text
    if used_search_tool:
        reply_text = format_items_urdu(menu_items, deals)
    else:
        reply_text = ai_response.content if hasattr(ai_response, "content") else str(ai_response)

    return {
        "success": True,
        "transcript": transcript,
        "reply": reply_text,
        "menu_items": menu_items,
        "deals": deals,
        "raw": reply_text,
    }


@app.get("/deals")
def get_all_deals():
    query = text("""
        SELECT 
            d.deal_id, 
            d.deal_name, 
            d.deal_price, 
            d.serving_size,
            d.image_url,
            string_agg(
                di.quantity::text || ' ' || mi.item_name,
                ', ' ORDER BY mi.item_id
            ) AS items
        FROM deal d
        JOIN deal_item di ON di.deal_id = d.deal_id
        JOIN menu_item mi ON mi.item_id = di.menu_item_id
        GROUP BY 
            d.deal_id, 
            d.deal_name, 
            d.deal_price, 
            d.serving_size,
            d.image_url
        ORDER BY d.deal_id;
    """)

    with SQL_ENGINE.connect() as conn:
        rows = conn.execute(query).mappings().all()

    return {"deals": rows}

@app.get("/upsell")
def get_upsell(city: str = "Islamabad"):
    """Weather-based upsell recommendations. No auth required."""
    return upsell_agent.weather_upsell(city)


@app.get("/cart/{cart_id}/recommendations")
def get_cart_recommendations(
    cart_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Rule-based cross-sell recommendations for items in the cart."""
    with SQL_ENGINE.connect() as conn:
        # Verify cart belongs to requesting user
        cart_row = conn.execute(
            text("SELECT user_id FROM cart WHERE cart_id = :cid LIMIT 1"),
            {"cid": cart_id},
        ).mappings().fetchone()

        if not cart_row or str(cart_row["user_id"]) != str(current_user["user_id"]):
            return {"recommendations": []}

        # Fetch cart items with their menu_item category
        items = conn.execute(
            text("""
                SELECT ci.item_id, ci.item_name, ci.item_type,
                       mi.item_category
                FROM cart_items ci
                LEFT JOIN menu_item mi ON mi.item_id = ci.item_id AND ci.item_type = 'menu_item'
                WHERE ci.cart_id = :cid
            """),
            {"cid": cart_id},
        ).mappings().all()

    if not items:
        return {"recommendations": []}

    all_names = [r["item_name"] for r in items if r["item_name"]]
    exclude_categories = {"drink", "side", "starter", "bread"}

    main_items = [
        r for r in items
        if r["item_type"] == "menu_item"
        and (r["item_category"] or "").lower() not in exclude_categories
    ]

    seen_recommendations: set = set()
    results: List[Dict] = []

    for item in main_items:
        rec = recommendation_engine.get_recommendation(item["item_name"], all_names)
        if not rec.get("success"):
            continue

        rec_name = rec["recommended_item"]
        if rec_name.lower() in seen_recommendations:
            continue
        seen_recommendations.add(rec_name.lower())

        # Look up item_id and price from menu_item table
        with SQL_ENGINE.connect() as conn:
            row = conn.execute(
                text("""
                    SELECT item_id, item_price
                    FROM menu_item
                    WHERE LOWER(item_name) = LOWER(:name)
                    LIMIT 1
                """),
                {"name": rec_name},
            ).mappings().fetchone()

        if not row:
            continue

        results.append({
            "for_item": item["item_name"],
            "recommended_name": rec_name,
            "recommended_item_id": int(row["item_id"]),
            "recommended_price": float(row["item_price"]),
            "reason": rec["reason"],
        })

    return {"recommendations": results}

@app.get("/health")
def health():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
