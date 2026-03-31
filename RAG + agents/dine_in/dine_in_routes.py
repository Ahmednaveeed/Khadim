import asyncio
from typing import Literal

from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import BaseModel, Field
from sqlalchemy import text

from agents.recommender_agent import RecommendationEngine
from infrastructure.db import SQL_ENGINE

router = APIRouter(prefix="/dine-in", tags=["dine-in"])
recommendation_engine = RecommendationEngine()


class TableLoginRequest(BaseModel):
    table_number: str
    pin: str


class DineInOrderItem(BaseModel):
    item_type: Literal["menu_item", "deal"]
    item_id: int
    quantity: int = Field(default=1, ge=1, le=99)


class DineInOrderRequest(BaseModel):
    session_id: str
    items: list[DineInOrderItem]


class DineInRecommendationSeedItem(BaseModel):
    item_type: Literal["menu_item", "deal", "custom_deal"] = "menu_item"
    item_id: int
    quantity: int = Field(default=1, ge=1, le=99)


class DineInRecommendationsRequest(BaseModel):
    session_id: str
    items: list[DineInRecommendationSeedItem]


@router.get("/top-sellers")
def get_top_sellers():
    with SQL_ENGINE.begin() as conn:
        top_menu_rows = (
            conn.execute(
                text(
                    """
                    SELECT
                        m.item_id,
                        m.item_name,
                        m.item_price,
                        m.item_category,
                        m.image_url,
                        COALESCE(SUM(oi.quantity), 0) AS sold_count
                    FROM public.menu_item m
                    LEFT JOIN public.order_items oi
                        ON oi.item_type = 'menu_item'
                       AND oi.item_id = m.item_id
                    LEFT JOIN public.orders o
                        ON o.order_id = oi.order_id
                       AND o.order_type = 'dine_in'
                    GROUP BY m.item_id, m.item_name, m.item_price, m.item_category, m.image_url
                    ORDER BY sold_count DESC, m.item_id ASC
                    LIMIT 5
                    """
                )
            )
            .mappings()
            .fetchall()
        )

        top_deal_rows = (
            conn.execute(
                text(
                    """
                    SELECT
                        d.deal_id,
                        d.deal_name,
                        d.deal_price,
                        d.image_url,
                        COALESCE(di.items, '') AS deal_items,
                        COALESCE(SUM(oi.quantity), 0) AS sold_count
                    FROM public.deal d
                    LEFT JOIN public.order_items oi
                        ON oi.item_type = 'deal'
                       AND oi.item_id = d.deal_id
                    LEFT JOIN public.orders o
                        ON o.order_id = oi.order_id
                       AND o.order_type = 'dine_in'
                    LEFT JOIN (
                        SELECT
                            di.deal_id,
                            STRING_AGG(
                                CONCAT(mi.item_name, ' x', di.quantity),
                                ', '
                                ORDER BY mi.item_name
                            ) AS items
                        FROM public.deal_item di
                        JOIN public.menu_item mi ON mi.item_id = di.menu_item_id
                        GROUP BY di.deal_id
                    ) di ON di.deal_id = d.deal_id
                    GROUP BY d.deal_id, d.deal_name, d.deal_price, d.image_url, di.items
                    ORDER BY sold_count DESC, d.deal_id ASC
                    LIMIT 3
                    """
                )
            )
            .mappings()
            .fetchall()
        )

    top_menu_items = [
        {
            "item_type": "menu_item",
            "item_id": int(row["item_id"]),
            "item_name": row["item_name"],
            "item_price": float(row["item_price"] or 0),
            "item_category": row["item_category"] or "",
            "image_url": row["image_url"] or "",
            "sold_count": int(row["sold_count"] or 0),
        }
        for row in top_menu_rows
    ]

    top_deals = [
        {
            "item_type": "deal",
            "item_id": int(row["deal_id"]),
            "item_name": row["deal_name"],
            "item_price": float(row["deal_price"] or 0),
            "item_category": "",
            "image_url": row["image_url"] or "",
            "deal_items": row["deal_items"] or "",
            "sold_count": int(row["sold_count"] or 0),
        }
        for row in top_deal_rows
    ]

    return {
        "top_menu_items": top_menu_items,
        "top_deals": top_deals,
        "top_sellers": [*top_menu_items, *top_deals],
    }


@router.post("/recommendations")
def get_dine_in_recommendations(payload: DineInRecommendationsRequest):
    if not payload.items:
        return {"recommendations": []}

    with SQL_ENGINE.begin() as conn:
        session_row = conn.execute(
            text(
                """
                SELECT session_id
                FROM public.dine_in_sessions
                WHERE session_id = :session_id
                  AND status = 'active'
                LIMIT 1
                """
            ),
            {"session_id": payload.session_id},
        ).mappings().fetchone()

        if not session_row:
            raise HTTPException(status_code=404, detail="Active dine-in session not found")

        cart_menu_items = []
        for seed in payload.items:
            if seed.item_type != "menu_item":
                continue

            row = conn.execute(
                text(
                    """
                    SELECT item_id, item_name, item_category
                    FROM public.menu_item
                    WHERE item_id = :item_id
                    LIMIT 1
                    """
                ),
                {"item_id": seed.item_id},
            ).mappings().fetchone()

            if not row:
                continue

            cart_menu_items.append(
                {
                    "item_id": int(row["item_id"]),
                    "item_name": row["item_name"],
                    "item_category": row["item_category"] or "",
                }
            )

        if not cart_menu_items:
            return {"recommendations": []}

        all_names = [row["item_name"] for row in cart_menu_items if row["item_name"]]
        exclude_categories = {"drink", "side", "starter", "bread"}

        main_items = [
            row
            for row in cart_menu_items
            if (row["item_category"] or "").lower() not in exclude_categories
        ]

        seen_recommendations: set[str] = set()
        current_item_ids = {int(row["item_id"]) for row in cart_menu_items}
        results = []

        for item in main_items:
            rec = recommendation_engine.get_recommendation(item["item_name"], all_names)
            if not rec.get("success"):
                continue

            rec_name = str(rec.get("recommended_item") or "").strip()
            if not rec_name:
                continue

            rec_key = rec_name.lower()
            if rec_key in seen_recommendations:
                continue

            rec_row = conn.execute(
                text(
                    """
                    SELECT item_id, item_price, image_url
                    FROM public.menu_item
                    WHERE LOWER(item_name) = LOWER(:name)
                    LIMIT 1
                    """
                ),
                {"name": rec_name},
            ).mappings().fetchone()

            if not rec_row:
                continue

            rec_item_id = int(rec_row["item_id"])
            if rec_item_id in current_item_ids:
                continue

            seen_recommendations.add(rec_key)

            results.append(
                {
                    "for_item": item["item_name"],
                    "recommended_name": rec_name,
                    "recommended_item_id": rec_item_id,
                    "recommended_price": float(rec_row["item_price"] or 0),
                    "image_url": rec_row["image_url"] or "",
                    "reason": rec.get("reason") or "",
                }
            )

    return {"recommendations": results}


@router.post("/table-login")
def table_login(payload: TableLoginRequest):
    table_number = payload.table_number.strip()
    pin = payload.pin.strip()

    with SQL_ENGINE.begin() as conn:
        table_row = conn.execute(
            text(
                """
                SELECT table_id, table_number, status
                FROM public.restaurant_tables
                WHERE table_number = :table_number
                  AND table_pin = :pin
                LIMIT 1
                """
            ),
            {"table_number": table_number, "pin": pin},
        ).mappings().fetchone()

        if not table_row:
            raise HTTPException(status_code=401, detail="Invalid table number or PIN")

        active_session_row = conn.execute(
            text(
                """
                SELECT session_id, table_id, started_at
                FROM public.dine_in_sessions
                WHERE table_id = :table_id
                  AND status = 'active'
                ORDER BY started_at DESC
                LIMIT 1
                """
            ),
            {"table_id": table_row["table_id"]},
        ).mappings().fetchone()

        if active_session_row:
            return {
                "session_id": str(active_session_row["session_id"]),
                "table_id": str(active_session_row["table_id"]),
                "table_number": table_row["table_number"],
                "started_at": active_session_row["started_at"].isoformat()
                if active_session_row["started_at"]
                else None,
            }

        if (table_row["status"] or "").lower() != "available":
            raise HTTPException(status_code=409, detail="Table is not available")

        session_row = conn.execute(
            text(
                """
                INSERT INTO public.dine_in_sessions (table_id, status)
                VALUES (:table_id, 'active')
                RETURNING session_id, table_id, started_at
                """
            ),
            {"table_id": table_row["table_id"]},
        ).mappings().fetchone()

        conn.execute(
            text(
                """
                UPDATE public.restaurant_tables
                SET status = 'occupied'
                WHERE table_id = :table_id
                """
            ),
            {"table_id": table_row["table_id"]},
        )

    return {
        "session_id": str(session_row["session_id"]),
        "table_id": str(session_row["table_id"]),
        "table_number": table_row["table_number"],
        "started_at": session_row["started_at"].isoformat() if session_row["started_at"] else None,
    }


@router.post("/order")
def create_dine_in_order(payload: DineInOrderRequest):
    if not payload.items:
        raise HTTPException(status_code=400, detail="At least one item is required")

    with SQL_ENGINE.begin() as conn:
        session_row = conn.execute(
            text(
                """
                SELECT session_id
                FROM public.dine_in_sessions
                WHERE session_id = :session_id
                  AND status = 'active'
                LIMIT 1
                """
            ),
            {"session_id": payload.session_id},
        ).mappings().fetchone()

        if not session_row:
            raise HTTPException(status_code=404, detail="Active dine-in session not found")

        normalized_items = []
        subtotal = 0.0

        for item in payload.items:
            if item.item_type == "menu_item":
                item_row = conn.execute(
                    text(
                        """
                        SELECT item_id, item_name, item_price
                        FROM public.menu_item
                        WHERE item_id = :item_id
                        LIMIT 1
                        """
                    ),
                    {"item_id": item.item_id},
                ).mappings().fetchone()

                if not item_row:
                    raise HTTPException(status_code=404, detail=f"Menu item {item.item_id} not found")

                snapshot_name = item_row["item_name"]
                snapshot_price = float(item_row["item_price"] or 0)
                resolved_item_id = int(item_row["item_id"])
            else:
                item_row = conn.execute(
                    text(
                        """
                        SELECT deal_id, deal_name, deal_price
                        FROM public.deal
                        WHERE deal_id = :item_id
                        LIMIT 1
                        """
                    ),
                    {"item_id": item.item_id},
                ).mappings().fetchone()

                if not item_row:
                    raise HTTPException(status_code=404, detail=f"Deal {item.item_id} not found")

                snapshot_name = item_row["deal_name"]
                snapshot_price = float(item_row["deal_price"] or 0)
                resolved_item_id = int(item_row["deal_id"])

            qty = int(item.quantity)
            line_total = round(snapshot_price * qty, 2)
            subtotal = round(subtotal + line_total, 2)

            normalized_items.append(
                {
                    "item_type": item.item_type,
                    "item_id": resolved_item_id,
                    "item_name": snapshot_name,
                    "quantity": qty,
                    "unit_price": snapshot_price,
                    "line_total": line_total,
                }
            )

        tax = round(subtotal * 0.05, 2)
        delivery_fee = 0.0
        total = round(subtotal + tax, 2)

        cart_row = conn.execute(
            text(
                """
                INSERT INTO public.cart (cart_id, status, user_id)
                VALUES (gen_random_uuid(), 'inactive', NULL)
                RETURNING cart_id
                """
            )
        ).mappings().fetchone()

        order_row = conn.execute(
            text(
                """
                INSERT INTO public.orders (
                    cart_id,
                    total_price,
                    subtotal,
                    tax,
                    delivery_fee,
                    order_type,
                    session_id,
                    status,
                    estimated_prep_time_minutes
                )
                VALUES (
                    :cart_id,
                    :total_price,
                    :subtotal,
                    :tax,
                    :delivery_fee,
                    'dine_in',
                    :session_id,
                    'confirmed',
                    15
                )
                RETURNING order_id
                """
            ),
            {
                "cart_id": cart_row["cart_id"],
                "total_price": total,
                "subtotal": subtotal,
                "tax": tax,
                "delivery_fee": delivery_fee,
                "session_id": payload.session_id,
            },
        ).mappings().fetchone()

        order_id = int(order_row["order_id"])

        from websocket_manager import manager

        try:
            asyncio.create_task(
                manager.broadcast(
                    room=f"session_{payload.session_id}",
                    message={"event": "new_order", "order_id": order_id, "total": total},
                )
            )
        except RuntimeError:
            # Fallback for worker-thread contexts where no running event loop is available.
            asyncio.run(
                manager.broadcast(
                    room=f"session_{payload.session_id}",
                    message={"event": "new_order", "order_id": order_id, "total": total},
                )
            )

        for item in normalized_items:
            conn.execute(
                text(
                    """
                    INSERT INTO public.order_items (
                        order_id,
                        item_type,
                        item_id,
                        name_snapshot,
                        unit_price_snapshot,
                        quantity,
                        line_total
                    )
                    VALUES (
                        :order_id,
                        :item_type,
                        :item_id,
                        :name_snapshot,
                        :unit_price_snapshot,
                        :quantity,
                        :line_total
                    )
                    """
                ),
                {
                    "order_id": order_id,
                    "item_type": item["item_type"],
                    "item_id": int(item["item_id"]),
                    "name_snapshot": item["item_name"],
                    "unit_price_snapshot": item["unit_price"],
                    "quantity": int(item["quantity"]),
                    "line_total": item["line_total"],
                },
            )

        conn.execute(
            text(
                """
                UPDATE public.dine_in_sessions
                SET round_count = COALESCE(round_count, 0) + 1,
                    total_amount = COALESCE(total_amount, 0) + :total
                WHERE session_id = :session_id
                """
            ),
            {"session_id": payload.session_id, "total": total},
        )

    return {
        "order_id": order_id,
        "session_id": str(payload.session_id),
        "total_price": total,
        "items": normalized_items,
    }


@router.websocket("/ws/session/{session_id}")
async def session_ws(websocket: WebSocket, session_id: str):
    from websocket_manager import manager

    await manager.connect(websocket, room=f"session_{session_id}")
    try:
        while True:
            await websocket.receive_text()  # keep alive
    except WebSocketDisconnect:
        manager.disconnect(websocket, room=f"session_{session_id}")
