import sys
sys.path.insert(0, ".")

from personalization.score_builder import ScoreBuilder
from infrastructure.database_connection import DatabaseConnection

# Test 1 - DB connection
db = DatabaseConnection.get_instance()
print("Test 1 - Connection:", db.test_connection())

# Test 2 - ScoreBuilder init
conn = db.get_connection()
builder = ScoreBuilder(conn)
print("Test 2 - ScoreBuilder init: OK")

# Test 3 - Build profile
result = builder.build_user_profile("3309b733-ed8c-41a5-b3a7-da6ed2d5501d")
print("Test 3 - Profile built:", result is not None)

# Test 4 - Verify saved in DB
with conn.cursor() as cur:
    cur.execute(
        "SELECT user_id FROM public.user_profiles WHERE user_id = %s",
        ("3309b733-ed8c-41a5-b3a7-da6ed2d5501d",)
    )
    row = cur.fetchone()
    print("Test 4 - Saved to DB:", row is not None)
