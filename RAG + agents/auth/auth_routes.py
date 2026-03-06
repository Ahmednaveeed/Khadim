# auth_routes.py
from typing import Optional, Dict, Any

from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, EmailStr
from sqlalchemy import text

from infrastructure.db import SQL_ENGINE
from auth.auth_utils import hash_password, verify_password, create_access_token, decode_token

router = APIRouter(prefix="/auth", tags=["auth"])
security = HTTPBearer()

class SignupRequest(BaseModel):
    full_name: str
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    password: str

class LoginRequest(BaseModel):
    identifier: str  # email OR phone
    password: str

def _is_email(value: str) -> bool:
    return "@" in value

def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> Dict[str, Any]:
    token = credentials.credentials
    payload = decode_token(token)
    if not payload or "sub" not in payload:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    user_id = payload["sub"]

    with SQL_ENGINE.connect() as conn:
        row = conn.execute(
            text("""
                SELECT user_id, full_name, email, phone, is_active, created_at
                FROM auth.app_users
                WHERE user_id = :user_id
            """),
            {"user_id": user_id}
        ).mappings().fetchone()

    if not row:
        raise HTTPException(status_code=401, detail="User not found")
    if row["is_active"] is False:
        raise HTTPException(status_code=403, detail="User is deactivated")

    return dict(row)

@router.post("/signup")
def signup(payload: SignupRequest):
    if not payload.email and not payload.phone:
        raise HTTPException(status_code=400, detail="Provide email or phone")

    password = payload.password.strip()

    if len(password.encode("utf-8")) > 72:
        raise HTTPException(
            status_code=400,
            detail="Password is too long (max 72 bytes). Please use a shorter password."
        )

    password_hash = hash_password(password)    

    with SQL_ENGINE.begin() as conn:
        if payload.email:
            exists = conn.execute(
                text("SELECT 1 FROM auth.app_users WHERE email = :email"),
                {"email": payload.email}
            ).fetchone()
            if exists:
                raise HTTPException(status_code=409, detail="Email already registered")

        if payload.phone:
            exists = conn.execute(
                text("SELECT 1 FROM auth.app_users WHERE phone = :phone"),
                {"phone": payload.phone}
            ).fetchone()
            if exists:
                raise HTTPException(status_code=409, detail="Phone already registered")

        row = conn.execute(
            text("""
                INSERT INTO auth.app_users (full_name, email, phone, password_hash)
                VALUES (:full_name, :email, :phone, :password_hash)
                RETURNING user_id, full_name, email, phone, created_at
            """),
            {
                "full_name": payload.full_name.strip(),
                "email": payload.email,
                "phone": payload.phone,
                "password_hash": password_hash,
            }
        ).mappings().fetchone()

        conn.execute(
            text("""
                INSERT INTO auth.user_preferences (user_id, preferences)
                VALUES (:user_id, '{}'::jsonb)
                ON CONFLICT (user_id) DO NOTHING
            """),
            {"user_id": row["user_id"]}
        )

    token = create_access_token(str(row["user_id"]))
    return {
        "user": {
            "user_id": str(row["user_id"]),
            "full_name": row["full_name"],
            "email": row["email"],
            "phone": row["phone"],
            "created_at": row["created_at"].isoformat() if row["created_at"] else None,
        },
        "access_token": token,
        "token_type": "bearer",
    }

@router.post("/login")
def login(payload: LoginRequest):
    identifier = payload.identifier.strip()
    field = "email" if _is_email(identifier) else "phone"

    with SQL_ENGINE.connect() as conn:
        row = conn.execute(
            text(f"""
                SELECT user_id, full_name, email, phone, password_hash, is_active, created_at
                FROM auth.app_users
                WHERE {field} = :identifier
                LIMIT 1
            """),
            {"identifier": identifier}
        ).mappings().fetchone()

    if not row:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    if row["is_active"] is False:
        raise HTTPException(status_code=403, detail="User is deactivated")

    if not verify_password(payload.password, row["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = create_access_token(str(row["user_id"]))
    return {
        "user": {
            "user_id": str(row["user_id"]),
            "full_name": row["full_name"],
            "email": row["email"],
            "phone": row["phone"],
            "created_at": row["created_at"].isoformat() if row["created_at"] else None,
        },
        "access_token": token,
        "token_type": "bearer",
    }

@router.get("/me")
def me(current_user: Dict[str, Any] = Depends(get_current_user)):
    return {"user": current_user}