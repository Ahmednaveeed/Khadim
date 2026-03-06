from typing import Dict, Any, Optional
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from infrastructure.db import SQL_ENGINE
from auth.auth_routes import get_current_user

router = APIRouter(prefix="/orders", tags=["orders"])

class PlaceOrderRequest(BaseModel):
    delivery_address: str = Field(default="N/A", min_length=2, max_length=500)
    delivery_fee: float = Field(default=2.99, ge=0.0, le=9999.0)
    tax_rate: float = Field(default=0.0, ge=0.0, le=1.0)


def _station_for_item(item_category: str, item_cuisine: str) -> str:
    if item_category == "drink":
        return "DRINKS"
    if item_category == "bread":
        return "TANDOOR"
    if item_cuisine == "BBQ":
        return "GRILL"
    if item_cuisine == "Chinese":
        return "WOK"
    if item_cuisine == "Desi":
        return "STOVE"
    return "FRY"


def _pick_chef_for_menu_item(menu_item_id: int, station: str) -> Optional[str]:
    q = text("""
        WITH candidates AS (
            SELECT c.cheff_name
            FROM menu_item_chefs mic
            JOIN chef c ON c.cheff_id = mic.chef_id
            WHERE mic.menu_item_id = :menu_item_id
              AND c.active_status = true
        ),
        load AS (
            SELECT assigned_chef, COUNT(*) AS cnt
            FROM kitchen_tasks
            WHERE status IN ('QUEUED', 'IN_PROGRESS')
            GROUP BY assigned_chef
        )
        SELECT cand.cheff_name
        FROM candidates cand
        LEFT JOIN load l ON l.assigned_chef = cand.cheff_name
        ORDER BY COALESCE(l.cnt, 0) ASC
        LIMIT 1
    """)
    with SQL_ENGINE.connect() as conn:
        row = conn.execute(q, {"menu_item_id": menu_item_id}).fetchone()
    return row[0] if row else None

from pydantic import BaseModel, Field



@router.post("/place_order")
def place_order(req: PlaceOrderRequest, current_user: Dict[str, Any] = Depends(get_current_user)):
    user_id = str(current_user["user_id"])

    res = place_order_sync(
        user_id=user_id,
        delivery_address=req.delivery_address,
        delivery_fee=req.delivery_fee,
        tax_rate=req.tax_rate,
    )

    if not res.get("success"):
        raise HTTPException(status_code=400, detail=res.get("message", "Failed to place order"))

    return res
    user_id = str(current_user["user_id"])

    with SQL_ENGINE.begin() as conn:
        # 1) Lock the active cart row (prevents double checkout)
        cart_row = conn.execute(
            text("""
                SELECT cart_id, status
                FROM cart
                WHERE user_id = :uid AND status = 'active'
                FOR UPDATE
            """),
            {"uid": user_id}
        ).mappings().fetchone()

        if not cart_row:
            raise HTTPException(status_code=400, detail="No active cart found")

        cart_id = str(cart_row["cart_id"])

        # 2) Idempotent: if an order already exists for this cart, return it
        existing = conn.execute(
            text("""
                SELECT order_id, status, total_price, subtotal, tax, delivery_fee, estimated_prep_time_minutes
                FROM orders
                WHERE cart_id = :cid
                LIMIT 1
            """),
            {"cid": cart_id}
        ).mappings().fetchone()

        if existing:
            return {
                "success": True,
                "order_id": int(existing["order_id"]),
                "status": existing["status"],
                "subtotal": float(existing["subtotal"] or 0),
                "tax": float(existing["tax"] or 0),
                "delivery_fee": float(existing["delivery_fee"] or 0),
                "total": float(existing["total_price"]),
                "estimated_prep_time_minutes": int(existing["estimated_prep_time_minutes"] or 0),
                "idempotent": True,
            }

        # 3) Move cart to checking_out (allowed by your cart_status_chk)
        conn.execute(
            text("UPDATE cart SET status='checking_out', updated_at=NOW() WHERE cart_id=:cid"),
            {"cid": cart_id}
        )

        # 4) Load cart items from DB
        cart_items = conn.execute(
            text("""
                SELECT item_id, item_type, item_name, quantity, unit_price
                FROM cart_items
                WHERE cart_id = :cid
            """),
            {"cid": cart_id}
        ).mappings().all()

        if not cart_items:
            conn.execute(
                text("UPDATE cart SET status='active', updated_at=NOW() WHERE cart_id=:cid"),
                {"cid": cart_id}
            )
            raise HTTPException(status_code=400, detail="Cart is empty")

        subtotal = round(sum(float(r["unit_price"] or 0) * int(r["quantity"] or 0) for r in cart_items), 2)
        tax = round(subtotal * float(req.tax_rate), 2)
        delivery_fee = float(req.delivery_fee)
        total = round(subtotal + tax + delivery_fee, 2)

        order_snapshot = {
            "items": [
                {
                    "item_id": int(r["item_id"]),
                    "item_type": r["item_type"],
                    "item_name": r["item_name"],
                    "quantity": int(r["quantity"]),
                    "unit_price": float(r["unit_price"]),
                    "line_total": round(float(r["unit_price"]) * int(r["quantity"]), 2),
                }
                for r in cart_items
            ],
            "subtotal": subtotal,
            "tax": tax,
            "delivery_fee": delivery_fee,
            "total": total,
        }

        # 5) Insert order
        try:
            order_row = conn.execute(
                text("""
                    INSERT INTO orders
                      (cart_id, total_price, order_data, status, delivery_address, subtotal, tax, delivery_fee)
                    VALUES
                      (:cart_id, :total_price, :order_data, 'CONFIRMED', :delivery_address, :subtotal, :tax, :delivery_fee)
                    RETURNING order_id
                """),
                {
                    "cart_id": cart_id,
                    "total_price": total,
                    "order_data": order_snapshot,
                    "delivery_address": req.delivery_address,
                    "subtotal": subtotal,
                    "tax": tax,
                    "delivery_fee": delivery_fee,
                }
            ).mappings().fetchone()
        except IntegrityError:
            # Race safety: if unique(cart_id) was hit, fetch existing and return
            existing = conn.execute(
                text("""
                    SELECT order_id, status, total_price, subtotal, tax, delivery_fee, estimated_prep_time_minutes
                    FROM orders
                    WHERE cart_id = :cid
                    LIMIT 1
                """),
                {"cid": cart_id}
            ).mappings().fetchone()

            if existing:
                return {
                    "success": True,
                    "order_id": int(existing["order_id"]),
                    "status": existing["status"],
                    "subtotal": float(existing["subtotal"] or 0),
                    "tax": float(existing["tax"] or 0),
                    "delivery_fee": float(existing["delivery_fee"] or 0),
                    "total": float(existing["total_price"]),
                    "estimated_prep_time_minutes": int(existing["estimated_prep_time_minutes"] or 0),
                    "idempotent": True,
                }
            raise

        order_id = int(order_row["order_id"])

        # 6) Insert order_items snapshots
        for r in cart_items:
            unit_price = float(r["unit_price"] or 0)
            qty = int(r["quantity"] or 0)
            conn.execute(
                text("""
                    INSERT INTO order_items
                      (order_id, item_type, item_id, name_snapshot, unit_price_snapshot, quantity, line_total)
                    VALUES
                      (:order_id, :item_type, :item_id, :name_snapshot, :unit_price_snapshot, :quantity, :line_total)
                """),
                {
                    "order_id": order_id,
                    "item_type": r["item_type"],
                    "item_id": int(r["item_id"]),
                    "name_snapshot": r["item_name"] or "",
                    "unit_price_snapshot": unit_price,
                    "quantity": qty,
                    "line_total": round(unit_price * qty, 2),
                }
            )

        # 7) Clear cart + mark inactive
        conn.execute(text("DELETE FROM cart_items WHERE cart_id = :cid"), {"cid": cart_id})
        conn.execute(text("UPDATE cart SET status='inactive', updated_at=NOW() WHERE cart_id = :cid"), {"cid": cart_id})

    return {
        "success": True,
        "order_id": order_id,
        "status": "CONFIRMED",
        "subtotal": subtotal,
        "tax": tax,
        "delivery_fee": delivery_fee,
        "total": total,
    }
    user_id = str(current_user["user_id"])

    with SQL_ENGINE.begin() as conn:
        # 1) Lock user's active cart (prevents double checkout)
        cart_row = conn.execute(
            text("""
                SELECT cart_id, status
                FROM cart
                WHERE user_id = :uid AND status = 'active'
                FOR UPDATE
            """),
            {"uid": user_id}
        ).mappings().fetchone()

        if not cart_row:
            raise HTTPException(status_code=400, detail="No active cart found")

        cart_id = str(cart_row["cart_id"])

        # 2) Idempotency: if an order already exists for this cart, return it
        existing = conn.execute(
            text("""
                SELECT order_id, status, total_price, subtotal, tax, delivery_fee, estimated_prep_time_minutes
                FROM orders
                WHERE cart_id = :cid
                LIMIT 1
            """),
            {"cid": cart_id}
        ).mappings().fetchone()

        if existing:
            return {
                "success": True,
                "order_id": int(existing["order_id"]),
                "status": existing["status"],
                "subtotal": float(existing["subtotal"] or 0),
                "tax": float(existing["tax"] or 0),
                "delivery_fee": float(existing["delivery_fee"] or 0),
                "total": float(existing["total_price"] or 0),
                "estimated_prep_time_minutes": int(existing["estimated_prep_time_minutes"] or 0),
                "idempotent": True,
            }

        # 3) Load cart items from DB
        cart_items = conn.execute(
            text("""
                SELECT item_id, item_type, item_name, quantity, unit_price
                FROM cart_items
                WHERE cart_id = :cid
            """),
            {"cid": cart_id}
        ).mappings().all()

        if not cart_items:
            raise HTTPException(status_code=400, detail="Cart is empty")

        subtotal = round(
            sum(float(r["unit_price"] or 0) * int(r["quantity"] or 0) for r in cart_items),
            2
        )
        tax = round(subtotal * float(req.tax_rate), 2)
        delivery_fee = float(req.delivery_fee)
        total = round(subtotal + tax + delivery_fee, 2)

        summary = {
            "items": [
                {
                    "item_id": int(r["item_id"]),
                    "item_type": r["item_type"],
                    "item_name": r["item_name"],
                    "quantity": int(r["quantity"]),
                    "unit_price": float(r["unit_price"]),
                    "total_price": round(float(r["unit_price"]) * int(r["quantity"]), 2),
                }
                for r in cart_items
            ],
            "subtotal": subtotal,
            "tax": tax,
            "delivery_fee": delivery_fee,
            "total": total,
            "success": True,
            "is_empty": False,
        }

        # 4) Insert order (status must match your CHECK constraint; using lowercase 'confirmed')
        try:
            order_row = conn.execute(
                text("""
                    INSERT INTO orders
                      (cart_id, total_price, order_data, status, delivery_address, subtotal, tax, delivery_fee)
                    VALUES
                      (:cart_id, :total_price, :order_data, 'confirmed', :delivery_address, :subtotal, :tax, :delivery_fee)
                    RETURNING order_id
                """),
                {
                    "cart_id": cart_id,
                    "total_price": total,
                    "order_data": summary,
                    "delivery_address": req.delivery_address,
                    "subtotal": subtotal,
                    "tax": tax,
                    "delivery_fee": delivery_fee,
                }
            ).mappings().fetchone()
        except IntegrityError:
            existing = conn.execute(
                text("""
                    SELECT order_id, status, total_price, subtotal, tax, delivery_fee, estimated_prep_time_minutes
                    FROM orders
                    WHERE cart_id = :cid
                    LIMIT 1
                """),
                {"cid": cart_id}
            ).mappings().fetchone()
            if existing:
                return {
                    "success": True,
                    "order_id": int(existing["order_id"]),
                    "status": existing["status"],
                    "subtotal": float(existing["subtotal"] or 0),
                    "tax": float(existing["tax"] or 0),
                    "delivery_fee": float(existing["delivery_fee"] or 0),
                    "total": float(existing["total_price"] or 0),
                    "estimated_prep_time_minutes": int(existing["estimated_prep_time_minutes"] or 0),
                    "idempotent": True,
                }
            raise

        order_id = int(order_row["order_id"])

        # 5) Insert order_items snapshots
        for r in cart_items:
            unit_price = float(r["unit_price"] or 0)
            qty = int(r["quantity"] or 0)

            conn.execute(
                text("""
                    INSERT INTO order_items
                      (order_id, item_type, item_id, name_snapshot, unit_price_snapshot, quantity, line_total)
                    VALUES
                      (:order_id, :item_type, :item_id, :name_snapshot, :unit_price_snapshot, :quantity, :line_total)
                """),
                {
                    "order_id": order_id,
                    "item_type": r["item_type"],
                    "item_id": int(r["item_id"]),
                    "name_snapshot": r["item_name"] or "",
                    "unit_price_snapshot": unit_price,
                    "quantity": qty,
                    "line_total": round(unit_price * qty, 2),
                }
            )

        # 6) Minimal kitchen tasks for menu items (expand deals later if needed)
        max_prep = 0
        for r in cart_items:
            if r["item_type"] != "menu_item":
                continue

            mid = int(r["item_id"])
            qty = int(r["quantity"] or 1)

            mi = conn.execute(
                text("""
                    SELECT item_name, item_category, item_cuisine, prep_time_minutes
                    FROM menu_item
                    WHERE item_id = :id
                """),
                {"id": mid}
            ).mappings().fetchone()

            if not mi:
                continue

            station = _station_for_item(mi["item_category"], mi["item_cuisine"])
            chef_name = _pick_chef_for_menu_item(mid, station) or "Unassigned"
            prep = int(mi["prep_time_minutes"] or 10)
            est = max(1, prep)
            max_prep = max(max_prep, est)

            seq = conn.execute(
                text("SELECT COUNT(*) FROM kitchen_tasks WHERE order_id = :oid"),
                {"oid": order_id}
            ).scalar_one()

            task_id = f"{order_id}-{int(seq) + 1}"

            conn.execute(
                text("""
                    INSERT INTO kitchen_tasks
                      (task_id, order_id, menu_item_id, item_name, qty, station, assigned_chef, estimated_minutes, status)
                    VALUES
                      (:task_id, :order_id, :menu_item_id, :item_name, :qty, :station, :assigned_chef, :estimated_minutes, 'QUEUED')
                """),
                {
                    "task_id": task_id,
                    "order_id": order_id,
                    "menu_item_id": mid,
                    "item_name": mi["item_name"],
                    "qty": qty,
                    "station": station,
                    "assigned_chef": chef_name,
                    "estimated_minutes": est,
                }
            )

        conn.execute(
            text("""
                UPDATE orders
                SET estimated_prep_time_minutes = :m, updated_at = NOW()
                WHERE order_id = :oid
            """),
            {"m": max_prep, "oid": order_id}
        )

        # 7) Clear cart items + mark inactive (status must be allowed by cart_status_chk)
        conn.execute(text("DELETE FROM cart_items WHERE cart_id = :cid"), {"cid": cart_id})
        conn.execute(text("UPDATE cart SET status='inactive', updated_at=NOW() WHERE cart_id = :cid"), {"cid": cart_id})

    return {
        "success": True,
        "order_id": order_id,
        "status": "confirmed",
        "subtotal": subtotal,
        "tax": tax,
        "delivery_fee": delivery_fee,
        "total": total,
        "estimated_prep_time_minutes": max_prep,
        "idempotent": False,
    }