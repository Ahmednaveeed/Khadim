# Backend File Guide

This document explains what each folder and file does in the backend project.

---

## Root Folder

- **main.py**: FastAPI entrypoint. Registers routers, CORS, startup warmup, and exposes API endpoints like `/chat`, `/voice_chat`, `/menu`, `/deals`, `/offers`, `/health`.
- **README.md**: Project overview and setup notes.
- **requirements.txt**: Python dependencies for backend services.
- **restaurantDB.sql**: Main SQL schema/data script for restaurant database setup.
- **run_all.bat**: Starts multiple backend agents/services using Python module commands.
- **.env**: Runtime environment variables (DB URL, keys, model paths, etc.).

System/generated folders in root:
- **.venv/**: Python virtual environment (generated).
- **env**: Alternate virtual environment folder in this workspace.
- **__pycache__/**: Python bytecode cache.

---

## auth/

Authentication and authorization utilities.

- **auth_routes.py**: FastAPI auth endpoints (register/login/token-related routes).
- **auth_utils.py**: Password hashing, token generation/validation, helper auth functions.
- **__init__.py**: Marks package.

---

## infrastructure/

Shared infrastructure services and low-level configuration.

- **config.py**: Shared constants/config values (channels, environment-driven settings).
- **database_connection.py**: PostgreSQL connection helper/singleton for agent workflows.
- **db.py**: SQLAlchemy engine/session setup used by API routes and queries.
- **redis_connection.py**: Redis client singleton used across agents and orchestrator.
- **redis_lock.py**: Redis-based locking primitives to avoid race conditions.
- **__init__.py**: Marks package.

---

## cart/

Cart domain logic and API surface.

- **cart_agent.py**: Redis task consumer for cart operations (create cart, add/remove items, summary, place order preparation).
- **cart_routes.py**: FastAPI cart endpoints for frontend integration.
- **__init__.py**: Marks package.

---

## orders/

Order creation, persistence, and coordination.

- **orders_service.py**: Core service methods for validating and processing orders.
- **order_agent.py**: Redis task consumer for order save/summarize operations.
- **order_coordinator.py**: Coordinates order workflow between cart, order, and downstream systems.
- **order_routes.py**: FastAPI order endpoints.
- **__init__.py**: Marks package.

---

## kitchen/

Kitchen task planning and status lifecycle.

- **kitchen_agent.py**: Redis task consumer that plans kitchen tasks, time estimates, and status updates.
- **kitchen_dashboard.py**: Streamlit dashboard for kitchen visibility and status tracking.
- **__init__.py**: Marks package.

---

## chat/

Conversational AI and prompt/tool-call behavior.

- **chat_agent.py**: Main AI response wrapper (LLM calls and tool-call extraction).
- **chat_logic.py**: Higher-level chat orchestration/business rules.
- **conversation_manager.py**: Conversation history/session memory utilities.
- **__init__.py**: Marks package.

---

## voice/

Speech input/output components.

- **transcribe.py**: Speech-to-text pipeline (Whisper model loading and transcription).
- **text_to_speech.py**: Text-to-speech utility (if voice output is needed).
- **__init__.py**: Marks package.

---

## retrieval/

Search and RAG-related components.

- **search_agent.py**: Menu/item search logic used by agents and tool calls.
- **rag_retriever.py**: Retrieval helper for relevant context chunks.
- **vector_store.py**: FAISS/vector index loading, embedding integration, retrieval operations.
- **__init__.py**: Marks package.

---

## agents/

Specialized recommendation/business agents and orchestrator.

- **orchestrator.py**: Streamlit app that coordinates end-to-end multi-agent flow via Redis.
- **recommender_agent.py**: Recommendation agent (item suggestions based on user context).
- **upsell_agent.py**: Upsell logic (contextual/weather/situation-based suggestions).
- **custom_deal_agent.py**: Custom deal creation/composition logic.
- **__init__.py**: Marks package.

---

## monitoring/

Operational visibility and lifecycle tools.

- **agent_health_dashboard.py**: Monitoring dashboard for agent health and responsiveness.
- **agent_lifecycle_manager.py**: Starts/stops/restarts agents and tracks service lifecycle status.
- **__init__.py**: Marks package.

---

## Databse/

Database SQL scripts (note: folder name appears to be misspelled, kept as-is).

- **resturant_postgre.sql**: PostgreSQL schema/data script variant.
- **db_updated.sql**: Updated SQL schema/data script.

---

## faiss_index/

Persisted retrieval index artifacts.

- **index.faiss**: FAISS vector index binary.
- **index.pkl**: Metadata/doc mapping used with FAISS index.

---

## Suggested Reading Order for New Developers

1. `main.py` (API surface and integration points)
2. `infrastructure/` (DB/Redis/config foundations)
3. `chat/` and `retrieval/` (AI + search pipeline)
4. `cart/` -> `orders/` -> `kitchen/` (order lifecycle)
5. `agents/orchestrator.py` (multi-agent full flow)
6. `monitoring/` dashboards for operations
