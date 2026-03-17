# custom_deal/custom_deal_routes.py

from typing import Dict, Any, List
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import text

from infrastructure.db import SQL_ENGINE
from auth.auth_routes import get_current_user

router = APIRouter(prefix="/custom-deal", tags=["custom_deal"])


class CustomDealItemIn(BaseModel):
    item_id: int
    item_name: str
    quantity: int = Field(ge=1)
    unit_price: float = Field(ge=0)


class SaveCustomDealRequest(BaseModel):
    group_size: int = Field(default=1, ge=1)
    total_price: float = Field(ge=0)
    discount_amount: float = Field(default=0.0, ge=0)
    items: List[CustomDealItemIn]


@router.post("/save")
def save_custom_deal(
    req: SaveCustomDealRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
) -> Dict[str, Any]:
    """
    Persist the AI-generated custom deal as a locked bundle.
    Returns the custom_deal_id which can then be added to cart
    as a single item_type='custom_deal' entry.
    """
    user_id = str(current_user["user_id"])

    if not req.items:
        raise HTTPException(status_code=400, detail="Deal must contain at least one item")

    with SQL_ENGINE.begin() as conn:
        # 1. Insert the deal bundle header
        deal_row = conn.execute(
            text("""
                INSERT INTO public.custom_deals
                    (user_id, group_size, total_price, discount_amount)
                VALUES
                    (:user_id, :group_size, :total_price, :discount_amount)
                RETURNING custom_deal_id
            """),
            {
                "user_id": user_id,
                "group_size": req.group_size,
                "total_price": round(req.total_price, 2),
                "discount_amount": round(req.discount_amount, 2),
            },
        ).mappings().fetchone()

        custom_deal_id = int(deal_row["custom_deal_id"])

        # 2. Insert each item in the bundle
        for item in req.items:
            # Verify the menu_item actually exists
            exists = conn.execute(
                text("SELECT 1 FROM public.menu_item WHERE item_id = :iid LIMIT 1"),
                {"iid": item.item_id},
            ).scalar()
            if not exists:
                raise HTTPException(
                    status_code=404,
                    detail=f"Menu item {item.item_id} ({item.item_name}) not found",
                )

            conn.execute(
                text("""
                    INSERT INTO public.custom_deal_items
                        (custom_deal_id, item_id, item_name, quantity, unit_price)
                    VALUES
                        (:custom_deal_id, :item_id, :item_name, :quantity, :unit_price)
                """),
                {
                    "custom_deal_id": custom_deal_id,
                    "item_id": item.item_id,
                    "item_name": item.item_name,
                    "quantity": item.quantity,
                    "unit_price": round(item.unit_price, 2),
                },
            )

    return {
        "success": True,
        "custom_deal_id": custom_deal_id,
        "message": "Custom deal saved successfully",
    }


@router.get("/{custom_deal_id}")
def get_custom_deal(
    custom_deal_id: int,
    current_user: Dict[str, Any] = Depends(get_current_user),
) -> Dict[str, Any]:
    """Fetch a saved custom deal and its items — used by cart display."""
    user_id = str(current_user["user_id"])

    with SQL_ENGINE.connect() as conn:
        deal = conn.execute(
            text("""
                SELECT custom_deal_id, user_id, group_size, total_price, discount_amount, created_at
                FROM public.custom_deals
                WHERE custom_deal_id = :cdid AND user_id = :uid
                LIMIT 1
            """),
            {"cdid": custom_deal_id, "uid": user_id},
        ).mappings().fetchone()

        if not deal:
            raise HTTPException(status_code=404, detail="Custom deal not found")

        items = conn.execute(
            text("""
                SELECT id, item_id, item_name, quantity, unit_price
                FROM public.custom_deal_items
                WHERE custom_deal_id = :cdid
                ORDER BY id
            """),
            {"cdid": custom_deal_id},
        ).mappings().all()

    return {
        "custom_deal_id": int(deal["custom_deal_id"]),
        "group_size": int(deal["group_size"]),
        "total_price": float(deal["total_price"]),
        "discount_amount": float(deal["discount_amount"]),
        "created_at": deal["created_at"].isoformat() if deal["created_at"] else None,
        "items": [
            {
                "item_id": int(i["item_id"]),
                "item_name": i["item_name"],
                "quantity": int(i["quantity"]),
                "unit_price": float(i["unit_price"]),
            }
            for i in items
        ],
    }
