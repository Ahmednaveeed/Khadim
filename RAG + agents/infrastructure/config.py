import os
from dotenv import load_dotenv

load_dotenv()

# Redis Channel Names
AGENT_TASKS_CHANNEL = "agent_tasks"
RESPONSE_CHANNEL_PREFIX = "response:"
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:1234@localhost:5432/restaurant")
