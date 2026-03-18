# Phase 2 - Personalization
"""
CollaborativeFilter — Layer 4 of the Personalization Agent.

Builds a User × Item rating matrix, computes cosine similarity
between users, and surfaces items liked by similar users that
the current user hasn't tried.

Gracefully handles sparse data — returns empty list when fewer
than 3 similar users are found (caller falls back to FAISS).

Uses raw psycopg2 (no ORM). Follows score_builder.py style.
"""

import logging
from typing import Any, Dict, List, Set, Tuple

import numpy as np
import psycopg2
import psycopg2.extras

logger = logging.getLogger(__name__)

# Attempt scipy import (needed for cosine_similarity)
try:
    from sklearn.metrics.pairwise import cosine_similarity as sk_cosine
    SKLEARN_AVAILABLE = True
except ImportError:
    logger.warning("scikit-learn not available — collaborative filtering disabled")
    SKLEARN_AVAILABLE = False
    sk_cosine = None


class CollaborativeFilter:
    """User-based collaborative filtering with sparse-data handling."""

    # Minimum similar users required to trust collab results
    MIN_SIMILAR_USERS = 3
    # Similarity threshold (cosine)
    SIMILARITY_THRESHOLD = 0.5
    # How many similar users to find
    TOP_K_USERS = 10

    def __init__(self, db_conn):
        """
        Parameters
        ----------
        db_conn : psycopg2 connection
        """
        self.conn = db_conn

    # ─────────────────────────────────────────────────────────────
    # Public API
    # ─────────────────────────────────────────────────────────────

    def get_suggestions(
        self,
        user_id: str,
        limit: int = 10,
    ) -> Tuple[List[Dict[str, Any]], str]:
        """
        Find items liked by users with similar taste profiles.

        Returns
        -------
        (results, source)
            results : list of {item_id, item_name, liked_by_count, source}
            source  : "collaborative_filtering" or "empty"

        Never raises — returns ([], "empty") on any failure.
        """
        if not SKLEARN_AVAILABLE:
            return [], "empty"

        try:
            # 1. Build user × item matrix
            matrix, user_ids, item_ids = self._build_rating_matrix()

            if user_id not in user_ids:
                logger.info("User %s has no ratings — collab filter skipped", user_id)
                return [], "empty"

            user_idx = user_ids.index(user_id)

            # 2. Compute cosine similarity for this user vs all others
            similar_users = self._find_similar_users(matrix, user_idx, user_ids)

            if len(similar_users) < self.MIN_SIMILAR_USERS:
                logger.info(
                    "Only %d similar users found for %s (need %d) — falling back",
                    len(similar_users), user_id, self.MIN_SIMILAR_USERS,
                )
                return [], "empty"

            # 3. Get items that similar users liked but this user hasn't tried
            already_ordered = self._get_ordered_item_ids(user_id)
            disliked = self._get_disliked_item_ids(user_id)
            exclude = already_ordered | disliked

            results = self._extract_suggestions(
                similar_users, item_ids, matrix, user_idx, exclude, limit,
            )

            return results, "collaborative_filtering"

        except Exception:
            logger.exception("Collaborative filtering failed for user %s", user_id)
            return [], "empty"

    # ─────────────────────────────────────────────────────────────
    # Matrix building
    # ─────────────────────────────────────────────────────────────

    def _build_rating_matrix(self) -> Tuple[np.ndarray, List[str], List[int]]:
        """
        Build a dense User × Item matrix where values are ratings (0 = unrated).

        Uses feedback table as the primary signal source.

        Returns (matrix, user_ids_list, item_ids_list)
        """
        with self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(
                """
                SELECT CAST(user_id AS TEXT) AS user_id,
                       item_id,
                       AVG(rating) AS avg_rating
                  FROM public.feedback
                 WHERE item_id IS NOT NULL
                   AND rating IS NOT NULL
                 GROUP BY user_id, item_id
                """
            )
            rows = cur.fetchall()

        if not rows:
            return np.array([]).reshape(0, 0), [], []

        # Collect unique users and items
        user_set: Dict[str, int] = {}
        item_set: Dict[int, int] = {}
        for r in rows:
            uid = r["user_id"]
            iid = r["item_id"]
            if uid not in user_set:
                user_set[uid] = len(user_set)
            if iid not in item_set:
                item_set[iid] = len(item_set)

        user_ids = list(user_set.keys())
        item_ids = list(item_set.keys())

        matrix = np.zeros((len(user_ids), len(item_ids)), dtype=np.float32)
        for r in rows:
            ui = user_set[r["user_id"]]
            ii = item_set[r["item_id"]]
            matrix[ui, ii] = float(r["avg_rating"])

        return matrix, user_ids, item_ids

    # ─────────────────────────────────────────────────────────────
    # User similarity
    # ─────────────────────────────────────────────────────────────

    def _find_similar_users(
        self,
        matrix: np.ndarray,
        user_idx: int,
        user_ids: List[str],
    ) -> List[Tuple[int, float]]:
        """
        Compute cosine similarity between target user and all others.
        Returns list of (user_idx, similarity) for users above threshold.
        """
        if matrix.shape[0] < 2:
            return []

        user_vec = matrix[user_idx].reshape(1, -1)
        similarities = sk_cosine(user_vec, matrix).flatten()  # type: ignore[misc]

        similar = []
        for i, sim in enumerate(similarities):
            if i == user_idx:
                continue
            if sim >= self.SIMILARITY_THRESHOLD:
                similar.append((i, float(sim)))

        # Sort by similarity descending
        similar.sort(key=lambda x: x[1], reverse=True)
        return similar[:self.TOP_K_USERS]

    # ─────────────────────────────────────────────────────────────
    # Suggestion extraction
    # ─────────────────────────────────────────────────────────────

    def _extract_suggestions(
        self,
        similar_users: List[Tuple[int, float]],
        item_ids: List[int],
        matrix: np.ndarray,
        user_idx: int,
        exclude_ids: Set[int],
        limit: int,
    ) -> List[Dict[str, Any]]:
        """
        Collect items rated 4-5★ by similar users that target user
        hasn't tried. Rank by frequency.
        """
        item_vote_count: Dict[int, int] = {}

        for other_idx, _sim in similar_users:
            for col_idx, iid in enumerate(item_ids):
                rating = matrix[other_idx, col_idx]
                if rating >= 4 and iid not in exclude_ids:
                    item_vote_count[iid] = item_vote_count.get(iid, 0) + 1

        if not item_vote_count:
            return []

        # Sort by vote count descending
        sorted_items = sorted(item_vote_count.items(), key=lambda x: x[1], reverse=True)

        results: List[Dict[str, Any]] = []
        for iid, count in sorted_items[:limit]:
            name = self._item_name(iid)
            results.append({
                "item_id": iid,
                "item_name": name,
                "liked_by_count": count,
                "source": "collaborative_filtering",
            })
        return results

    # ─────────────────────────────────────────────────────────────
    # DB helpers (same pattern as score_builder.py)
    # ─────────────────────────────────────────────────────────────

    def _item_name(self, item_id: int) -> str:
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

    def _get_ordered_item_ids(self, user_id: str) -> Set[int]:
        try:
            with self.conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT DISTINCT oi.item_id
                      FROM public.order_items oi
                      JOIN public.orders o ON o.order_id = oi.order_id
                      JOIN public.cart c   ON c.cart_id  = o.cart_id
                     WHERE c.user_id = %s
                       AND oi.item_type = 'menu_item'
                    """,
                    (user_id,),
                )
                return {r[0] for r in cur.fetchall()}
        except Exception:
            return set()

    def _get_disliked_item_ids(self, user_id: str) -> Set[int]:
        try:
            with self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(
                    """
                    SELECT disliked_items
                      FROM public.user_profiles
                     WHERE user_id = %s
                    """,
                    (user_id,),
                )
                row = cur.fetchone()
                if row and isinstance(row["disliked_items"], list):
                    return set(row["disliked_items"])
        except Exception:
            pass
        return set()
