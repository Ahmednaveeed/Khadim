# Phase 2 - Personalization
"""
Pydantic model for the user_profiles table.
Stores preprocessed preference data for each user to enable fast
recommendation queries.
"""

from datetime import datetime
from typing import Any, Dict, List, Optional
from uuid import UUID

from pydantic import BaseModel, Field


class TopItem(BaseModel):
    """Single entry inside user_profiles.top_items JSONB array."""
    item_id: int
    item_name: str
    score: float
    order_count: int = 0
    last_ordered: Optional[str] = None          # ISO-8601 date string


class TopDeal(BaseModel):
    """Single entry inside user_profiles.top_deals JSONB array."""
    deal_id: int
    deal_name: str
    score: float
    selected_count: int = 0


class UserProfile(BaseModel):
    """Mirrors the public.user_profiles row."""
    profile_id: Optional[int] = None
    user_id: UUID

    preferred_cuisines: List[str] = Field(default_factory=list)
    top_items: List[TopItem] = Field(default_factory=list)
    top_deals: List[TopDeal] = Field(default_factory=list)
    disliked_items: List[int] = Field(default_factory=list)

    preference_vector: Dict[str, Any] = Field(default_factory=dict)
    # Raw {item_id: score} map — keys are stringified item_ids

    cached_recommendations: Optional[Dict[str, Any]] = None
    cached_recommendations_ts: Optional[datetime] = None

    last_updated: datetime = Field(default_factory=datetime.utcnow)
    created_at: datetime = Field(default_factory=datetime.utcnow)
