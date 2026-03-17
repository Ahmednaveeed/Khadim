from pydantic import BaseModel, Field
from typing import Optional, List


class FeedbackCreateRequest(BaseModel):
    rating: int = Field(..., ge=1, le=5)
    message: str
    order_id: Optional[int] = None
    item_id: Optional[int] = None
    deal_id: Optional[int] = None
    custom_deal_id: Optional[int] = None
    feedback_type: Optional[str] = "GENERAL"


class ItemRating(BaseModel):
    item_id: int
    rating: int = Field(..., ge=1, le=5)


class CustomDealFeedbackRequest(BaseModel):
    order_id: int
    custom_deal_id: int
    overall_rating: int = Field(..., ge=1, le=5)
    message: str
    item_ratings: Optional[List[ItemRating]] = []