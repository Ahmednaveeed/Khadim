# orders/orders_service.py
from typing import Dict, Any, Optional
from fastapi import HTTPException
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
import json

from infrastructure.db import SQL_ENGINE


def place_order_sync(
    cart_id: str,
    delivery_address: str = "N/A",
    delivery_fee: float = 0.0,
    tax_rate: float = 0.0,
) -> Dict[str, Any]:
    """
    Places an order for the given cart_id.
    - Locks the active cart row (FOR UPDATE)
    - Idempotent: if order already exists for cart_id, returns it
    - Inserts orders + order_items
    - Marks cart inactive and clears cart_items
    """

    try:
        with SQL_ENGINE.begin() as conn:
            # 1) Lock cart row
            cart_row = conn.execute(
                text("""
                    SELECT cart_id, user_id, status
                    FROM cart
                    WHERE cart_id = :cid
                    FOR UPDATE
                """),
                {"cid": cart_id},
            ).mappings().fetchone()

            if not cart_row:
                raise HTTPException(status_code=404, detail="Cart not found")

            if (cart_row["status"] or "").lower() != "active":
                raise HTTPException(status_code=400, detail=f"Cart is not active (status={cart_row['status']})")

            # 2) Idempotent behavior
            existing = conn.execute(
                text("""
                    SELECT order_id, status, total_price, subtotal, tax, delivery_fee, estimated_prep_time_minutes
                    FROM orders
                    WHERE cart_id = :cid
                    LIMIT 1
                """),
                {"cid": cart_id},
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

            # 3) Move cart to checking_out
            conn.execute(
                text("UPDATE cart SET status='checking_out', updated_at=NOW() WHERE cart_id=:cid"),
                {"cid": cart_id},
            )

            # 4) Load cart items
            cart_items = conn.execute(
                text("""
                    SELECT item_id, item_type, item_name, quantity, unit_price
                    FROM cart_items
                    WHERE cart_id = :cid
                """),
                {"cid": cart_id},
            ).mappings().all()

            if not cart_items:
                conn.execute(
                    text("UPDATE cart SET status='active', updated_at=NOW() WHERE cart_id=:cid"),
                    {"cid": cart_id},
                )
                raise HTTPException(status_code=400, detail="Cart is empty")

            subtotal = round(sum(float(r["unit_price"] or 0) * int(r["quantity"] or 0) for r in cart_items), 2)
            tax = round(subtotal * float(tax_rate), 2)
            delivery_fee = float(delivery_fee)
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

            # IMPORTANT: jsonb expects json string (with ::jsonb cast)
            order_data_json = json.dumps(summary)

            # 5) Insert order
            try:
                order_row = conn.execute(
                    text("""
                        INSERT INTO orders
                          (cart_id, total_price, order_data, status, delivery_address, subtotal, tax, delivery_fee)
                        VALUES
                          (:cart_id, :total_price, :order_data::jsonb, 'confirmed', :delivery_address, :subtotal, :tax, :delivery_fee)
                        RETURNING order_id
                    """),
                    {
                        "cart_id": cart_id,
                        "total_price": total,
                        "order_data": order_data_json,
                        "delivery_address": delivery_address,
                        "subtotal": subtotal,
                        "tax": tax,
                        "delivery_fee": delivery_fee,
                    },
                ).mappings().fetchone()
            except IntegrityError:
                # race: unique(cart_id)
                existing = conn.execute(
                    text("""
                        SELECT order_id, status, total_price, subtotal, tax, delivery_fee, estimated_prep_time_minutes
                        FROM orders
                        WHERE cart_id = :cid
                        LIMIT 1
                    """),
                    {"cid": cart_id},
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

            # 6) Insert order_items
            for r in cart_items:
                unit_price = float(r["unit_price"] or 0)
                qty = int(r["quantity"] or 0)
                line_total = round(unit_price * qty, 2)

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
                        "name_snapshot": (r["item_name"] or ""),
                        "unit_price_snapshot": unit_price,
                        "quantity": qty,
                        "line_total": line_total,
                    },
                )

            # 7) Clear cart + mark inactive
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
            }

    except HTTPException:
        raise
    except Exception as e:
        # This ensures you SEE the real error instead of silent 500
        raise HTTPException(status_code=500, detail=f"place_order_sync failed: {repr(e)}")