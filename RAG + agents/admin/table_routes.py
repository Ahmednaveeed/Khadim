from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import text

from infrastructure.db import SQL_ENGINE

router = APIRouter(prefix="/admin/tables", tags=["admin-tables"])


class CreateTableRequest(BaseModel):
    table_number: str
    table_pin: str = Field(min_length=1)


@router.post("")
def create_table(payload: CreateTableRequest):
    table_number = payload.table_number.strip()
    table_pin = payload.table_pin.strip()

    if not table_number or not table_pin:
        raise HTTPException(status_code=400, detail="table_number and table_pin are required")

    with SQL_ENGINE.begin() as conn:
        row = conn.execute(
            text(
                """
                INSERT INTO public.restaurant_tables (table_number, table_pin, status)
                VALUES (:table_number, :table_pin, 'available')
                RETURNING table_id, table_number, status
                """
            ),
            {"table_number": table_number, "table_pin": table_pin},
        ).mappings().fetchone()

    return {
        "table_id": str(row["table_id"]),
        "table_number": row["table_number"],
        "status": row["status"],
    }


@router.get("")
def list_tables():
    with SQL_ENGINE.connect() as conn:
        rows = conn.execute(
            text(
                """
                SELECT
                    t.table_id,
                    t.table_number,
                    t.status,
                    s.session_id,
                    s.round_count,
                    s.total_amount
                FROM public.restaurant_tables t
                LEFT JOIN public.dine_in_sessions s
                    ON s.table_id = t.table_id
                   AND s.status = 'active'
                ORDER BY t.table_number
                """
            )
        ).mappings().fetchall()

    tables = []
    for row in rows:
        tables.append(
            {
                "table_id": str(row["table_id"]),
                "table_number": row["table_number"],
                "status": row["status"],
                "session_id": str(row["session_id"]) if row["session_id"] else None,
                "round_count": int(row["round_count"] or 0),
                "total_amount": float(row["total_amount"] or 0),
            }
        )

    return {"tables": tables}


@router.patch("/{table_id}/close")
def close_table(table_id: str):
    with SQL_ENGINE.begin() as conn:
        conn.execute(
            text(
                """
                UPDATE public.dine_in_sessions
                SET status = 'closed', ended_at = NOW()
                WHERE table_id = :table_id
                  AND status = 'active'
                """
            ),
            {"table_id": table_id},
        )

        table_update = conn.execute(
            text(
                """
                UPDATE public.restaurant_tables
                SET status = 'available'
                WHERE table_id = :table_id
                """
            ),
            {"table_id": table_id},
        )

        if table_update.rowcount == 0:
            raise HTTPException(status_code=404, detail="Table not found")

    return {"success": True, "message": "Table closed"}


@router.get("/{table_id}/orders")
def get_table_orders(table_id: str):
    with SQL_ENGINE.connect() as conn:
        session_row = conn.execute(
            text(
                """
                SELECT session_id
                FROM public.dine_in_sessions
                WHERE table_id = :table_id
                  AND status = 'active'
                LIMIT 1
                """
            ),
            {"table_id": table_id},
        ).mappings().fetchone()

        if not session_row:
            raise HTTPException(status_code=404, detail="No active session for this table")

        rows = conn.execute(
            text(
                """
                SELECT
                    o.order_id,
                    o.session_id,
                    o.status,
                    o.total_price,
                    o.created_at
                FROM public.orders o
                JOIN public.dine_in_sessions s ON s.session_id = o.session_id
                WHERE s.table_id = :table_id
                  AND s.status = 'active'
                ORDER BY o.created_at DESC
                """
            ),
            {"table_id": table_id},
        ).mappings().fetchall()

    orders = []
    for row in rows:
        orders.append(
            {
                "order_id": int(row["order_id"]),
                "session_id": str(row["session_id"]) if row["session_id"] else None,
                "status": row["status"],
                "total_price": float(row["total_price"] or 0),
                "created_at": row["created_at"].isoformat() if row["created_at"] else None,
            }
        )

    return {
        "table_id": table_id,
        "session_id": str(session_row["session_id"]),
        "orders": orders,
    }
