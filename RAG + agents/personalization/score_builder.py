# Phase 2 - Personalization
"""
ScoreBuilder — Layer 2 of the Personalization Agent.

Fetches user signals (orders, feedback, favourites, soft ratings),
applies time-decayed scoring, and upserts the result into the
public.user_profiles table.

Uses raw psycopg2 queries (no ORM) following the pattern of
infrastructure/database_connection.py.
"""

import json
import logging
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

import psycopg2
import psycopg2.extras

logger = logging.getLogger(__name__)


class ScoreBuilder:
    """Builds / refreshes a user preference profile."""

    # ── Scoring weights (from implementation plan Layer 2) ────
    WEIGHT_FAVOURITE = 40
    WEIGHT_RATING_HIGH = 30       # rating >= 4
    WEIGHT_RATING_MID = 10        # rating 2-3
    WEIGHT_RATING_LOW = -40       # rating <= 1
    WEIGHT_ORDER_FREQUENT = 20    # ordered 3+ times (× decay)
    WEIGHT_ORDER_OCCASIONAL = 10  # ordered 1-2 times (× decay)
    WEIGHT_SOFT_RATING = 15       # soft_rating >= 4

    def __init__(self, db_conn):
        """
        Parameters
        ----------
        db_conn : psycopg2 connection
            Raw psycopg2 connection obtained via
            DatabaseConnection.get_instance().get_connection()
        """
        self.conn = db_conn

    # ─────────────────────────────────────────────────────────────
    # Public API
    # ─────────────────────────────────────────────────────────────

    def build_user_profile(self, user_id: str) -> dict:
        """Main entry point — build or refresh the full profile."""
        try:
            signals = self._fetch_user_signals(user_id)
            scores = self._calculate_item_scores(signals)

            top_items = self._extract_top_items(scores, limit=10)
            top_deals = self._extract_top_deals(signals, limit=5)
            preferred_cuisines = self._extract_preferred_cuisines(user_id, signals)
            disliked_items = self._extract_disliked_items(signals, scores)

            profile_data = {
                "preferred_cuisines": preferred_cuisines,
                "top_items": top_items,
                "top_deals": top_deals,
                "disliked_items": disliked_items,
                "preference_vector": {str(k): v for k, v in scores.items()},
            }

            self._upsert_user_profile(user_id, profile_data)
            logger.info("Profile built for user %s (%d items scored)", user_id, len(scores))
            return profile_data

        except Exception:
            logger.exception("Failed to build profile for user %s", user_id)
            raise

    def invalidate_cache(self, user_id: str) -> None:
        """Set cached_recommendations and ts to NULL for this user."""
        try:
            with self.conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE public.user_profiles
                       SET cached_recommendations    = NULL,
                           cached_recommendations_ts = NULL
                     WHERE user_id = %s
                    """,
                    (user_id,),
                )
            self.conn.commit()
            logger.info("Cache invalidated for user %s", user_id)
        except Exception:
            self.conn.rollback()
            logger.exception("Failed to invalidate cache for user %s", user_id)

    # ─────────────────────────────────────────────────────────────
    # Signal fetching
    # ─────────────────────────────────────────────────────────────

    def _fetch_user_signals(self, user_id: str) -> dict:
        """
        Query purchase history, feedback, favourites, and soft ratings.
        Returns a dict with keys: orders, feedback, favourites, soft_ratings.
        """
        signals: Dict[str, Any] = {
            "orders": [],
            "feedback": [],
            "favourites": [],
            "soft_ratings": [],
        }

        try:
            with self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:

                # 1. Purchase history — order_items joined with orders
                cur.execute(
                    """
                    SELECT oi.item_id,
                           oi.item_type,
                           oi.name_snapshot AS item_name,
                           oi.quantity,
                           o.created_at     AS order_date
                      FROM public.order_items oi
                      JOIN public.orders o  ON o.order_id  = oi.order_id
                      JOIN public.cart   c  ON c.cart_id   = o.cart_id
                     WHERE c.user_id = %s
                       AND oi.item_type = 'menu_item'
                     ORDER BY o.created_at DESC
                    """,
                    (user_id,),
                )
                signals["orders"] = cur.fetchall()

                # 2. Feedback (ratings)
                cur.execute(
                    """
                    SELECT item_id, deal_id, rating, created_at
                      FROM public.feedback
                     WHERE user_id = %s
                       AND rating IS NOT NULL
                     ORDER BY created_at DESC
                    """,
                    (user_id,),
                )
                signals["feedback"] = cur.fetchall()

                # 3. Favourites
                cur.execute(
                    """
                    SELECT item_id, deal_id, custom_deal_id, created_at
                      FROM public.favourites
                     WHERE user_id = %s
                    """,
                    (user_id,),
                )
                signals["favourites"] = cur.fetchall()

                # 4. Soft ratings from custom deal items
                cur.execute(
                    """
                    SELECT cdi.item_id, cdi.soft_rating
                      FROM public.custom_deal_items cdi
                      JOIN public.custom_deals cd ON cd.custom_deal_id = cdi.custom_deal_id
                     WHERE cd.user_id = %s
                       AND cdi.soft_rating IS NOT NULL
                    """,
                    (user_id,),
                )
                signals["soft_ratings"] = cur.fetchall()

        except Exception:
            logger.exception("Failed to fetch signals for user %s", user_id)

        return signals

    # ─────────────────────────────────────────────────────────────
    # Time decay
    # ─────────────────────────────────────────────────────────────

    @staticmethod
    def _apply_time_decay(days_ago: int) -> float:
        """
        Time-decay multiplier per implementation plan:
          ≤30 days  → 1.0
          31–90     → 0.7
          91–180    → 0.4
          >180      → 0.1
        """
        if days_ago <= 30:
            return 1.0
        if days_ago <= 90:
            return 0.7
        if days_ago <= 180:
            return 0.4
        return 0.1

    # ─────────────────────────────────────────────────────────────
    # Scoring
    # ─────────────────────────────────────────────────────────────

    def _calculate_item_scores(self, signals: dict) -> Dict[int, float]:
        """
        Apply scoring weights from implementation plan Layer 2.

        Returns {item_id: composite_score}.
        """
        scores: Dict[int, float] = {}
        now = datetime.now(timezone.utc)

        # Helper to ensure item_id key exists
        def _ensure(item_id: int) -> None:
            if item_id not in scores:
                scores[item_id] = 0.0

        # ── Favourites (+40) ─────────────────────────────────────
        for fav in signals.get("favourites", []):
            iid = fav.get("item_id")
            if iid is not None:
                _ensure(iid)
                scores[iid] += self.WEIGHT_FAVOURITE

        # ── Feedback ratings ─────────────────────────────────────
        # Aggregate per item (average rating)
        item_ratings: Dict[int, List[int]] = {}
        for fb in signals.get("feedback", []):
            iid = fb.get("item_id")
            rating = fb.get("rating")
            if iid is not None and rating is not None:
                item_ratings.setdefault(iid, []).append(int(rating))

        for iid, ratings in item_ratings.items():
            _ensure(iid)
            avg = sum(ratings) / len(ratings)
            if avg >= 4:
                scores[iid] += self.WEIGHT_RATING_HIGH
            elif avg >= 2:
                scores[iid] += self.WEIGHT_RATING_MID
            if avg <= 1:
                scores[iid] += self.WEIGHT_RATING_LOW

        # ── Order frequency with time decay ──────────────────────
        item_order_info: Dict[int, List[int]] = {}   # item_id → [days_ago, …]
        for order in signals.get("orders", []):
            iid = order.get("item_id")
            order_date = order.get("order_date")
            if iid is None or order_date is None:
                continue
            if isinstance(order_date, str):
                order_date = datetime.fromisoformat(order_date)
            days_ago = max((now - order_date).days, 0)
            item_order_info.setdefault(iid, []).append(days_ago)

        for iid, days_list in item_order_info.items():
            _ensure(iid)
            order_count = len(days_list)
            # Use the most recent order for time decay
            min_days = min(days_list)
            decay = self._apply_time_decay(min_days)

            if order_count >= 3:
                scores[iid] += self.WEIGHT_ORDER_FREQUENT * decay
            elif order_count >= 1:
                scores[iid] += self.WEIGHT_ORDER_OCCASIONAL * decay

        # ── Soft ratings (≥4 → +15) ─────────────────────────────
        for sr in signals.get("soft_ratings", []):
            iid = sr.get("item_id")
            rating = sr.get("soft_rating")
            if iid is not None and rating is not None and int(rating) >= 4:
                _ensure(iid)
                scores[iid] += self.WEIGHT_SOFT_RATING

        return scores

    # ─────────────────────────────────────────────────────────────
    # Extraction helpers
    # ─────────────────────────────────────────────────────────────

    def _extract_top_items(self, scores: Dict[int, float], limit: int = 10) -> list:
        """Return top N items sorted by score, enriched with name/order info."""
        sorted_ids = sorted(scores, key=scores.get, reverse=True)[:limit]  # type: ignore[arg-type]

        result: List[Dict[str, Any]] = []
        for iid in sorted_ids:
            if scores[iid] <= 0:
                continue
            # Look up item name from DB
            name = self._item_name(iid)
            result.append({
                "item_id": iid,
                "item_name": name,
                "score": round(scores[iid], 2),
                "order_count": 0,       # will be enriched by caller if needed
                "last_ordered": None,
            })
        return result

    def _extract_top_deals(self, signals: dict, limit: int = 5) -> list:
        """Derive top deals from favourited deals + feedback on deals."""
        deal_scores: Dict[int, float] = {}

        # Favourited deals
        for fav in signals.get("favourites", []):
            did = fav.get("deal_id")
            if did is not None:
                deal_scores[did] = deal_scores.get(did, 0) + self.WEIGHT_FAVOURITE

        # Deal feedback
        for fb in signals.get("feedback", []):
            did = fb.get("deal_id")
            rating = fb.get("rating")
            if did is not None and rating is not None:
                deal_scores.setdefault(did, 0)
                if int(rating) >= 4:
                    deal_scores[did] += self.WEIGHT_RATING_HIGH
                elif int(rating) >= 2:
                    deal_scores[did] += self.WEIGHT_RATING_MID

        sorted_ids = sorted(deal_scores, key=deal_scores.get, reverse=True)[:limit]  # type: ignore[arg-type]
        result: List[Dict[str, Any]] = []
        for did in sorted_ids:
            if deal_scores[did] <= 0:
                continue
            name = self._deal_name(did)
            result.append({
                "deal_id": did,
                "deal_name": name,
                "score": round(deal_scores[did], 2),
                "selected_count": 0,
            })
        return result

    def _extract_preferred_cuisines(self, user_id, signals: dict) -> list:
        """Derive top cuisines from order history item categories."""
        cuisine_counts: Dict[str, int] = {}
        item_ids = set()
        for order in signals.get("orders", []):
            iid = order.get("item_id")
            if iid is not None:
                item_ids.add(iid)

        if not item_ids:
            return []

        try:
            with self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                # Fetch categories for ordered items
                cur.execute(
                    """
                    SELECT mi.item_cuisine AS cuisine,
                           SUM(oi.quantity) AS total_ordered
                      FROM public.order_items oi
                      JOIN public.menu_item mi ON mi.item_id = oi.item_id
                      JOIN public.orders o     ON o.order_id  = oi.order_id
                      JOIN public.cart c       ON c.cart_id   = o.cart_id
                     WHERE c.user_id = %s
                       AND oi.item_type = 'menu_item'
                       AND mi.item_cuisine IS NOT NULL
                     GROUP BY mi.item_cuisine
                     ORDER BY total_ordered DESC
                    """,
                    (user_id,),
                )

                for row in cur.fetchall():
                    cuisine = row.get("cuisine") or "Unknown"
                    cuisine_counts[cuisine] = cuisine_counts.get(cuisine, 0) + 1
        except Exception:
            logger.exception("Failed to fetch cuisines")

        # Sort by count descending, return top 5
        return sorted(cuisine_counts, key=cuisine_counts.get, reverse=True)[:5]  # type: ignore[arg-type]

    def _extract_disliked_items(self, signals: dict, scores: Dict[int, float]) -> list:
        """Items with rating ≤2 OR composite score < -10."""
        disliked: set = set()

        # Items rated ≤2
        for fb in signals.get("feedback", []):
            iid = fb.get("item_id")
            rating = fb.get("rating")
            if iid is not None and rating is not None and int(rating) <= 2:
                disliked.add(iid)

        # Items with overall score < -10
        for iid, sc in scores.items():
            if sc < -10:
                disliked.add(iid)

        return sorted(disliked)

    # ─────────────────────────────────────────────────────────────
    # DB helpers
    # ─────────────────────────────────────────────────────────────

    def _item_name(self, item_id: int) -> str:
        """Fetch item_name from menu_item."""
        try:
            with self.conn.cursor() as cur:
                cur.execute(
                    "SELECT item_name FROM public.menu_item WHERE item_id = %s",
                    (item_id,),
                )
                row = cur.fetchone()
                return row[0] if row else f"Item #{item_id}"
        except Exception:
            return f"Item #{item_id}"

    def _deal_name(self, deal_id: int) -> str:
        """Fetch deal_name from deal."""
        try:
            with self.conn.cursor() as cur:
                cur.execute(
                    "SELECT deal_name FROM public.deal WHERE deal_id = %s",
                    (deal_id,),
                )
                row = cur.fetchone()
                return row[0] if row else f"Deal #{deal_id}"
        except Exception:
            return f"Deal #{deal_id}"

    def _upsert_user_profile(self, user_id: str, profile_data: dict) -> None:
        """INSERT … ON CONFLICT DO UPDATE into user_profiles."""
        try:
            with self.conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO public.user_profiles (
                        user_id,
                        preferred_cuisines,
                        top_items,
                        top_deals,
                        disliked_items,
                        preference_vector,
                        last_updated
                    ) VALUES (
                        %s, %s, %s, %s, %s, %s, NOW()
                    )
                    ON CONFLICT (user_id) DO UPDATE SET
                        preferred_cuisines  = EXCLUDED.preferred_cuisines,
                        top_items           = EXCLUDED.top_items,
                        top_deals           = EXCLUDED.top_deals,
                        disliked_items      = EXCLUDED.disliked_items,
                        preference_vector   = EXCLUDED.preference_vector,
                        last_updated        = NOW()
                    """,
                    (
                        user_id,
                        json.dumps(profile_data["preferred_cuisines"]),
                        json.dumps(profile_data["top_items"]),
                        json.dumps(profile_data["top_deals"]),
                        json.dumps(profile_data["disliked_items"]),
                        json.dumps(profile_data["preference_vector"]),
                    ),
                )
            self.conn.commit()
        except Exception:
            self.conn.rollback()
            logger.exception("Failed to upsert profile for user %s", user_id)
            raise
