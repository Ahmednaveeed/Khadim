# Khadim - AI-Powered Restaurant Management System

A full-stack restaurant ordering and management platform featuring dual customer interfaces (delivery app & in-restaurant kiosk), AI-powered conversational ordering, real-time order tracking, and comprehensive admin dashboards.

---

## 📋 Project Overview

Khadim is a monorepo application designed to streamline restaurant operations across multiple touchpoints:

- **Multi-platform Flutter app** with two distinct flavors:
  - **Delivery Mode**: Traditional e-commerce ordering with authentication and delivery tracking
  - **Kiosk Mode**: Table-based ordering using PIN authentication for dine-in restaurant patrons
  
- **FastAPI backend** with AI agents for:
  - Conversational ordering (text & voice)
  - Personalized recommendations
  - Custom deal generation
  - Order orchestration and fulfillment
  - Kitchen task management
  
- **Voice processing** with Whisper-based speech recognition and text-to-speech capabilities

---

## 🏗️ Architecture

### Monorepo Structure

```
├── App/                          # Flutter application
│   ├── lib/
│   │   ├── main.dart            # Customer delivery app entry
│   │   ├── main_kiosk.dart      # Kiosk dine-in app entry
│   │   ├── models/              # Data models
│   │   ├── providers/           # State management
│   │   ├── screens/             # UI screens
│   │   ├── services/            # API integration, config
│   │   ├── themes/              # UI theming
│   │   └── utils/               # Utilities
│   └── pubspec.yaml
│
├── RAG + agents/                # FastAPI backend
│   ├── main.py                  # FastAPI app entry
│   ├── auth/                    # Authentication & authorization
│   ├── cart/                    # Shopping cart logic
│   ├── orders/                  # Order processing & persistence
│   ├── kitchen/                 # Kitchen task planning & dashboard
│   ├── chat/                    # AI conversation & orchestration
│   ├── agents/                  # Specialized AI agents
│   ├── custom_deal/             # Dynamic deal generation
│   ├── dine_in/                 # Table ordering logic
│   ├── admin/                   # Admin dashboards & analytics
│   ├── infrastructure/          # DB, Redis, config
│   └── requirements.txt
│
├── voice/                       # Voice processing
│   ├── transcribe.py            # Whisper speech-to-text
│   ├── text_to_speech.py        # TTS output
│   ├── finetune_whisper.py      # Model fine-tuning
│   └── requirements.txt
│
├── Database/
│   └── db_new(USE THIS).sql     # PostgreSQL schema & seed data
│
└── docs/
    ├── SETUP_NOTES.md           # Development setup guide
    ├── BACKEND_FILE_GUIDE.md    # Backend architecture details
    └── restaurant_side.md
```

### Data Flow

**Customer Delivery Flow:**
1. Auth via JWT token
2. Browse menu → Add to cart (Redis)
3. Checkout → Create order (PostgreSQL)
4. Track delivery in real-time
5. Submit feedback

**Kiosk Dine-In Flow:**
1. Table PIN authentication (no JWT required)
2. Browse menu → Add to cart (in-memory DineInProvider)
3. Send order round directly to kitchen (no checkout)
4. Multiple rounds per session supported
5. Waiter call system for table service

---

## 🚀 Quick Start

### Prerequisites
- Python 3.9+
- Flutter SDK
- PostgreSQL 12+
- FFmpeg (for voice processing)
- Node.js (optional, for web build)

### Backend Setup (One-Time)

```bash
cd "RAG + agents"
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt

# Install ffmpeg (Windows)
winget install ffmpeg
```

Create `.env` file:
```env
DATABASE_URL=postgresql://postgres:<PASSWORD>@localhost:5432/KhadimDB
GROQ_API_KEY=<YOUR_GROQ_API_KEY>
```

Import database:
```bash
psql -U postgres -d KhadimDB -f "..\Database\db_new(USE THIS).sql"
```

### Run Backend

```bash
cd "RAG + agents"
venv\Scripts\activate
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

API docs available at: `http://localhost:8000/docs`

### Run Flutter App

**Customer Delivery (Web):**
```bash
cd App
flutter pub get
flutter run -d chrome --target lib/main.dart
```

**Kiosk Dine-In (Mobile/Web):**
```bash
# Android
flutter run -d <device-id> --target lib/main_kiosk.dart

# Web
flutter run -d chrome --target lib/main_kiosk.dart
```

### Access Dashboards

- **Kitchen Dashboard**: `http://localhost:8000/kitchen/dashboard` (FastAPI-hosted)
- **Admin Dashboard**: Backend admin endpoints (guard: `admin@gmail.com`)

---

## 🔑 Key Features

### AI-Powered Ordering
- **Chat Agent**: Conversational menu exploration with tool-calling
- **Voice Support**: Urdu-optimized Whisper model for speech-to-text
- **Personalization**: Recommendation engine based on order history, category scoring, and similarity search

### Multi-Channel Ordering
- **Delivery**: Traditional cart checkout with payment integration
- **Dine-In**: Table-based PIN ordering with multiple order rounds

### Kitchen Operations
- Real-time order tracking with time estimates
- Task planning and status lifecycle management
- Kitchen dashboard with order filtering and prioritization

### Admin Analytics
- Revenue tracking by category (main, side, drink, starter, bread)
- Trend analysis and insights
- Agent performance monitoring
- Custom deal and offer management

### Order Management
- Cart persistence (Redis for delivery, in-memory for dine-in)
- Order persistence with Postgres
- Feedback collection and sentiment analysis
- Favourite items tracking
- Custom deal generation via AI Agent

---

## 🛠️ Tech Stack

### Frontend
- **Framework**: Flutter (Dart)
- **State Management**: Provider
- **Storage**: SharedPreferences, SQLite (local)
- **HTTP**: Dio

### Backend
- **Framework**: FastAPI (Python)
- **ORM**: SQLAlchemy
- **Database**: PostgreSQL
- **Cache**: Redis
- **AI Models**: Groq LLM, Whisper (speech), Text-to-speech
- **Task Queue**: Redis task consumer pattern

### Voice
- **STT**: OpenAI Whisper (fine-tuned for Urdu)
- **TTS**: Text-to-speech library
- **Preprocessing**: Audio denoise and normalization

---

## 📊 Database Schema

Key tables:
- `users` - Authentication & profiles
- `menu_items` - Menu catalog with categories (main, side, drink, starter, bread)
- `orders` - Order records with delivery/dine-in metadata
- `order_items` - Order line items
- `cart_sessions` - Cart state (delivery flow)
- `dine_in_sessions` - Dine-in table sessions with table_id
- `restaurant_tables` - Physical table configurations
- `custom_deals`, `favourites`, `user_profiles` - Personalization
- `admin_analytics` - Revenue and trend data

---

## ⚙️ Configuration

### API Endpoints (Flutter ↔ Backend)

**Flutter `lib/services/api_config.dart`:**
- Web: `http://localhost:8000`
- Mobile: `http://192.168.100.30:8000` (update for your network)

**Main Backend Endpoints:**
- `POST /chat` - Chat API (text-based conversation)
- `POST /voice_chat` - Voice API (speech input)
- `POST /cart/create` - Initialize cart
- `POST /orders/create` - Create order
- `GET /menu` - Fetch menu items
- `POST /dine-in/table-login` - Kiosk table authentication
- `GET /admin/*` - Admin dashboards (protected)

---

## 🚨 Important Notes & Gotchas

### Kiosk Dine-In
- **Table-to-Order Linkage**: Orders must persist `table_id` from session; kitchen dashboard relies on this join
- **Session-Scoped Tracking**: Use dine-in specific endpoints (`/dine-in/sessions/{session_id}/orders`) rather than delivery order APIs
- **No JWT Recovery**: Kiosk table sessions don't require app-user JWT; if customer wants to log in, table-login must return valid JWT
- **Multi-Round Orders**: Each order round is a separate POST to `/dine-in/order`; cart is reset between rounds

### Cart & Orders
- **Delivery**: Cart persisted in Redis; checkout finalizes to PostgreSQL order
- **Dine-In**: Cart in-memory (DineInProvider); order rounds sent directly to kitchen without checkout

### Admin Revenue
- Revenue filtering uses canonical category values: `main`, `side`, `drink`, `starter`, `bread`
- UI displays plurals (Sides, Starters) but sends singular API values
- Backend normalizes aliases (sides→side, drinks→drink, etc.)

### Voice Processing
- Whisper model must be Urdu-optimized for quality transcription
- FFmpeg required for audio processing (system-wide)
- Voice endpoints route through chat agent for intent extraction

---

## 📱 Development Team Guide

See [SETUP_NOTES.md](docs/SETUP_NOTES.md) for:
- Step-by-step environment setup
- Running individual components
- Database import procedures
- API testing workflows

See [BACKEND_FILE_GUIDE.md](docs/BACKEND_FILE_GUIDE.md) for:
- Backend module descriptions
- Agent architecture
- Infrastructure details

---

## 🔐 Security

- JWT token-based auth for delivery app
- PIN-based table authentication for kiosk (stateless per session)
- Admin endpoints protected by role check (`admin@gmail.com`)
- Password hashing with bcrypt
- Separate user authentication contexts for delivery vs. dine-in

---

## 📝 License

Proprietary - Final Year Project (FYP)

---

## 👥 Team

Built by the Khadim development team at FAST. For support, contact team members or check documentation in `/docs`.
