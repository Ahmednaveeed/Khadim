Good clarifications. Let me check what was already in the plan and what's new, then give you the updated version.

**Already in the plan:** Direct-to-kitchen on order confirm, 3-option payment, kitchen tracking, card wiped on session timeout, no saved cards persisted.

**New/changed from your clarifications:**

- main.dart stays as is (noted)
- Home screen: same top (custom deal banner) + top sellers instead of personalization
- Menu and deals screens: identical to customer app
- Cart flow: same cart UX → confirm → goes to kitchen (no payment at this step)
- Order history screen: shows placed orders, amount, status "To Be Paid"
- Order tracking: same as customer app
- Profile: no address editing, but card can be added via settings (wiped on session end)

Here is the fully updated plan.

**Khadim - Dine-In Mode Implementation Plan (Final)**

**Project:** Khadim - AI Multi-Agent Restaurant Automation  
**Feature:** Restaurant-Side Dine-In Ordering (Tablet Kiosk)  
**Date:** March 31, 2026  
**Version:** 3.0 - Two-App Architecture, PIN Login, Aligned UI  
**Status:** Final - Approved for Implementation

**Executive Summary**

Khadim currently serves customers through a Flutter mobile app supporting delivery and takeaway, backed by a multi-agent FastAPI backend. This plan extends the platform with a **dine-in mode** for restaurant tablets, delivered as a **separate Flutter application** built from the same codebase using Flutter build flavors.

The kiosk app shares the same visual design language as the customer app. The experience feels familiar - same menu, same cart, same deals - but the underlying flow is different: orders go directly to the kitchen without immediate payment, the bill accumulates across multiple rounds, and payment happens once at the end of the dining experience.

The two apps share one codebase, one backend, and one database. They are separated at the entry point level via Flutter flavors, producing two independent APKs suitable for separate Play Store listings.

**Architecture Overview**

text

┌─────────────────────────┐ ┌──────────────────────────────┐

│ "Khadim" (Customer) │ │ "Khadim Restaurant" (Kiosk) │

│ Flavor: customer │ │ Flavor: kiosk │

│ Entry: main.dart │ │ Entry: main_kiosk.dart │

│ Play Store: Public │ │ Play Store: Restricted │

│ Login: Email/Phone │ │ Login: Table PIN │

│ Mode: Delivery │ │ Mode: Dine-In │

└────────────┬────────────┘ └──────────────┬───────────────┘

│ │

└────────────┬────────────────────┘

│

┌──────────▼──────────┐

│ FastAPI Backend │

│ │

│ JWT "type" field │

│ delivery / dine_in │

└──────────┬──────────┘

│

┌──────────▼──────────┐

│ PostgreSQL + Redis │

│ + FAISS Index │

└─────────────────────┘

**What Stays Completely Untouched**

- All existing delivery/takeaway agents (order, upsell, custom deal, personalization, re-engagement)
- Customer app main.dart, login, signup, and session flow
- FAISS, RAG, voice, and chat agents
- Existing cart → checkout → confirmation delivery flow for customers
- Feedback, favourites, and personalization for delivery users

**Phase 1 - Flutter Project Setup (Flavors)**

**1.1 - Entry Point Files**

main.dart stays exactly as it is - the customer app entry point, untouched.

A new kiosk entry point is added alongside it:

text

App/lib/

├── main.dart ← untouched, existing customer app

├── main_kiosk.dart ← NEW: kiosk entry point

└── app_config.dart ← NEW: flavor config

**app_config.dart:**

dart

**enum** AppFlavor { customer, kiosk }

**class** AppConfig {

**static** AppFlavor flavor = AppFlavor.customer;

**static** bool **get** isKiosk => flavor == AppFlavor.kiosk;

**static** bool **get** isCustomer => flavor == AppFlavor.customer;

}

**main_kiosk.dart:**

dart

**void** main() {

AppConfig.flavor = AppFlavor.kiosk;

runApp(KhadimKioskApp());

}

**class** KhadimKioskApp **extends** StatelessWidget {

@override

Widget build(BuildContext context) {

**return** MaterialApp(

title: 'Khadim Restaurant',

theme: AppTheme.theme, _// same theme as customer app_

initialRoute: '/kiosk/login',

routes: {

'/kiosk/login': (\_) => TablePinScreen(),

'/kiosk/home': (\_) => DineInHomeScreen(),

'/kiosk/menu': (\_) => MenuScreen(), _// shared_

'/kiosk/deals': (\_) => DealScreen(), _// shared_

'/kiosk/cart': (\_) => CartScreen(), _// shared, modified behavior_

'/kiosk/orders': (\_) => DineInOrderHistoryScreen(),

'/kiosk/tracking': (\_) => OrderTrackingScreen(), _// shared_

'/kiosk/payment': (\_) => DineInPaymentScreen(),

'/kiosk/cash': (\_) => CashWaitingScreen(),

'/kiosk/thankyou': (\_) => ThankYouResetScreen(),

'/kiosk/settings': (\_) => DineInSettingsScreen(),

},

);

}

}

**1.2 - Android Flavor Configuration**

**App/android/app/build.gradle:**

text

android {

flavorDimensions "app"

productFlavors {

customer {

dimension "app"

applicationId "com.khadim.app"

resValue "string", "app_name", "Khadim"

}

kiosk {

dimension "app"

applicationId "com.khadim.restaurant"

resValue "string", "app_name", "Khadim Restaurant"

}

}

}

**1.3 - App Icons**

text

App/android/app/src/

├── customer/res/mipmap-\*/ ← Khadim customer icon

└── kiosk/res/mipmap-\*/ ← Khadim Restaurant icon

**1.4 - Build Commands**

bash

_\# Development_

flutter run --flavor customer --target lib/main.dart

flutter run --flavor kiosk --target lib/main_kiosk.dart

_\# Production builds_

flutter build apk --flavor customer --target lib/main.dart

flutter build apk --flavor kiosk --target lib/main_kiosk.dart

**Phase 2 - Database Changes**

**2.1 - New Table: restaurant_tables**

sql

**CREATE** **TABLE** restaurant_tables (

table_id UUID **PRIMARY** **KEY** **DEFAULT** gen_random_uuid(),

restaurant_id UUID **REFERENCES** restaurants(restaurant_id),

table*number **VARCHAR**(10) NOT NULL, *\-- "T1", "T2", "T3"\_

table*pin **VARCHAR**(6) NOT NULL, *\-- 4-6 digit PIN, admin-generated\_

qr*token **VARCHAR**(64) **UNIQUE**, *\-- optional QR, future use\_

**status** **VARCHAR**(30) **DEFAULT** 'available',

_\-- available | occupied | bill_requested_cash |_

_\-- bill_requested_card | cleaning_

created_at **TIMESTAMP** **DEFAULT** NOW()

);

**CREATE** **INDEX** idx_tables_restaurant **ON** restaurant_tables(restaurant_id);

**CREATE** **INDEX** idx_tables_status **ON** restaurant_tables(**status**);

**2.2 - New Table: dine_in_sessions**

sql

**CREATE** **TABLE** dine_in_sessions (

session_id UUID **PRIMARY** **KEY** **DEFAULT** gen_random_uuid(),

table_id UUID **REFERENCES** restaurant_tables(table_id),

started_at **TIMESTAMP** **DEFAULT** NOW(),

ended_at **TIMESTAMP**,

**status** **VARCHAR**(30) **DEFAULT** 'active',

_\-- active | payment_pending_cash |_

_\-- payment_pending_card | closed_

payment*method **VARCHAR**(20), *\-- cash | card | online\_

total_amount **DECIMAL**(10,2) **DEFAULT** 0,

round*count **INT** **DEFAULT** 0 *\-- increments per order round\_

);

**CREATE** **INDEX** idx_sessions_table **ON** dine_in_sessions(table_id);

**CREATE** **INDEX** idx_sessions_status **ON** dine_in_sessions(**status**);

**2.3 - Changes to Existing orders Table**

sql

**ALTER** **TABLE** orders

**ADD** **COLUMN** order_type **VARCHAR**(20) **DEFAULT** 'delivery',

_\-- delivery | dine_in_

**ADD** **COLUMN** table_id UUID **REFERENCES** restaurant_tables(table_id),

**ADD** **COLUMN** session_id UUID **REFERENCES** dine_in_sessions(session_id),

**ADD** **COLUMN** round_number **INT**,

**ADD** **COLUMN** payment_status **VARCHAR**(20) **DEFAULT** NULL;

_\-- null for delivery | to_be_paid | paid for dine_in_

**Phase 3 - Backend (FastAPI)**

**3.1 - New Endpoint: Table PIN Login**

**Added to auth/auth_routes.py:**

python

@router.post("/auth/table-login")

**async** **def** table_login(credentials: TableLoginRequest):

"""

Kiosk-only login. Validates table_number + PIN.

Creates a dine-in session and returns a short-lived JWT.

"""

table = db.query(RestaurantTable).filter_by(

table_number=credentials.table_number,

table_pin=credentials.pin

).first()

**if** **not** table:

**raise** HTTPException(401, "Invalid table number or PIN")

**if** table.status == 'occupied':

**raise** HTTPException(409, "Table session already active")

_\# Create session_

session = DineInSession(table_id=table.table_id)

db.add(session)

table.status = 'occupied'

db.commit()

token = create_jwt({

"sub": str(table.table_id),

"type": "dine_in",

"role": "table",

"table_id": str(table.table_id),

"table_number": table.table_number,

"session_id": str(session.session_id),

"restaurant_id": str(table.restaurant_id),

"exp": datetime.utcnow() + timedelta(hours=6)

})

**return** {"access_token": token, "session_id": str(session.session_id)}

**3.2 - New File: dine_in/dine_in_routes.py**

text

POST /dine-in/order

Receives confirmed cart items.

Skips payment step - fires directly to kitchen agent via Redis.

Increments session round_count and total_amount.

Order saved with payment_status = "to_be_paid".

Pushes WebSocket event to kitchen dashboard.

GET /dine-in/session/{session_id}/orders

Returns all order rounds placed in this session,

each with items, amounts, timestamps, and status.

Used by order history screen and running bill.

GET /dine-in/top-sellers

Returns top 10 menu items ranked by order frequency

and average rating - used on kiosk home screen

instead of personalized recommendations.

POST /dine-in/sessions/{session_id}/request-bill

Customer signals they are done ordering.

Session status → payment_pending_cash or payment_pending_card.

Pushes bill_requested event to kitchen dashboard.

POST /dine-in/sessions/{session_id}/confirm-cash

Staff-only (requires staff/admin JWT).

Confirms cash received.

All session orders updated: payment_status → paid.

Session closed. Table status → cleaning.

Pushes payment_confirmed WebSocket event to tablet.

POST /dine-in/sessions/{session_id}/pay

Card/online payment via gateway in guest/one-time mode.

Card details never stored.

On success: orders marked paid, session closed,

table → cleaning, WebSocket event pushed to tablet.

POST /dine-in/sessions/{session_id}/close

Internal cleanup on thank-you screen timeout.

**3.3 - New File: admin/table_routes.py**

text

POST /admin/tables

Admin creates table. Provides table_number.

Backend auto-generates 6-digit PIN.

Returns table credentials for staff.

GET /admin/tables

All tables with live status and active session summary.

PUT /admin/tables/{table_id}

Edit table number. Regenerate PIN on demand.

DELETE /admin/tables/{table_id}

Delete only if status is available.

POST /admin/tables/{table_id}/mark-ready

Staff marks table cleaned.

Status: cleaning → available.

**3.4 - New File: dine_in/websocket_manager.py**

python

**class** TableWebSocketManager:

**def** \__init_\_(self):

self.tablet_connections: dict\[str, WebSocket\] = {}

self.kitchen_subscribers: list\[WebSocket\] = \[\]

**async** **def** connect_tablet(self, table_id: str, ws: WebSocket):

**await** ws.accept()

self.tablet_connections\[str(table_id)\] = ws

**async** **def** connect_kitchen(self, ws: WebSocket):

**await** ws.accept()

self.kitchen_subscribers.append(ws)

**async** **def** send_to_tablet(self, table_id: str, event: dict):

ws = self.tablet_connections.get(str(table_id))

**if** ws:

**await** ws.send_json(event)

**async** **def** broadcast_to_kitchen(self, event: dict):

**for** ws **in** self.kitchen_subscribers:

**await** ws.send_json(event)

**async** **def** disconnect_tablet(self, table_id: str):

self.tablet_connections.pop(str(table_id), None)

**Registered in main.py:**

python

@app.websocket("/ws/table/{table_id}")

**async** **def** tablet_ws(table_id: str, websocket: WebSocket):

**await** manager.connect_tablet(table_id, websocket)

@app.websocket("/ws/kitchen")

**async** **def** kitchen_ws(websocket: WebSocket):

**await** manager.connect_kitchen(websocket)

**3.5 - Changes to Existing Backend Files**

| **File**                     | **Change**                                                                         |
| ---------------------------- | ---------------------------------------------------------------------------------- |
| kitchen/kitchen_agent.py     | Accept order_type, table_id, table_number, round_number on dine-in orders          |
| kitchen/kitchen_dashboard.py | Add Table Status Panel + Confirm Cash + Mark Ready buttons                         |
| orders/order_routes.py       | Skip delivery address validation when order_type == dine_in                        |
| cart/cart_routes.py          | When type == dine_in in JWT, cart confirm calls /dine-in/order instead of checkout |
| main.py                      | Register new routers + WebSocket endpoints                                         |

**Phase 4 - Kiosk App UI & Screens**

The kiosk app shares the same visual design as the customer app. Layout, typography, colors, and component styles are identical. Only content and behavior differ where the dine-in flow requires it.

**Screen-by-Screen Breakdown**

**table_pin_screen.dart ← NEW**

**Purpose:** Kiosk boot screen - staff enters table credentials to start a session.

- Restaurant logo + name at top
- Table number field
- 6-digit PIN pad (large tablet-friendly buttons)
- "Start Session" button
- Calls POST /auth/table-login
- On success: stores JWT, navigates to /kiosk/home

**dinein_home_screen.dart ← NEW**

**Purpose:** Kiosk home - same layout as customer home but with different content blocks.

| **Section**     | **Customer App**             | **Kiosk App**                    |
| --------------- | ---------------------------- | -------------------------------- |
| Top banner      | Custom Deal creator          | Custom Deal creator (same)       |
| Below banner    | Personalized recommendations | Top Sellers / Liked by Customers |
| Navigation      | Home, Menu, Offers, Profile  | Home, Menu, Deals, Orders        |
| Floating button | Mic (voice/chat)             | Mic (voice/chat, same)           |
| Header          | User name                    | "Table \[number\]"               |

Top Sellers section fetches from GET /dine-in/top-sellers - returns top 10 items by order frequency and rating. No personalization logic needed since there is no user history.

**menu_screen.dart ← SHARED (minor conditional)**

**Purpose:** Browse full menu - identical UI to customer app.

One conditional added:

dart

_// In add-to-cart action:_

**if** (AppConfig.isKiosk) {

_// Add to local dine-in cart (same CartProvider)_

} **else** {

_// Existing delivery cart flow_

}

No other changes. Menu browsing, search, filters - all identical.

**deal_screen.dart ← SHARED (unchanged)**

**Purpose:** Browse deals - identical to customer app, zero changes needed.

**cart_screen.dart ← SHARED (one behavioral change)**

**Purpose:** Review cart items before confirming order.

UI is identical - items, quantities, totals, edit/remove. One change in the confirm action:

dart

onConfirmOrder() {

**if** (AppConfig.isKiosk) {

_// Send directly to kitchen via POST /dine-in/order_

_// No payment step here_

dineInService.placeOrderRound(cartItems, sessionId);

navigateTo('/kiosk/orders'); _// → order history with "To Be Paid" status_

} **else** {

_// Existing checkout flow_

navigateTo('/checkout');

}

}

The "Confirm Order" button label also changes:

- Customer app: **"Proceed to Checkout"**
- Kiosk app: **"Send to Kitchen"**

**dinein_order_history_screen.dart ← NEW**

**Purpose:** Shows all order rounds placed in the current session.

text

Session Orders - Table 4

Round 1 • 8:42 PM

Zinger Burger × 2 Rs. 800

Crispy Fries × 1 Rs. 150

Status: To Be Paid

Round 2 • 9:15 PM

Pepsi × 2 Rs. 200

Status: To Be Paid

─────────────────────────────────────

Total Rs. 1,150

\[ Request Bill \] \[ Back to Home \]

- Fetches from GET /dine-in/session/{session_id}/orders
- "Request Bill" button navigates to payment method selection
- "Back to Home" returns to dine-in home screen
- Status shows "To Be Paid" until payment confirmed, then "Paid"

**order_tracking_screen.dart ← SHARED (unchanged)**

**Purpose:** Track kitchen preparation status - identical to customer app. Kitchen agent already updates order status in real time; same screen works for dine-in orders.

**dine_in_payment_screen.dart ← NEW**

**Purpose:** Payment method selection after "Request Bill."

Three options:

**Cash:**

- Tapped → navigates to CashWaitingScreen
- Session status → payment_pending_cash
- Kitchen dashboard shows "Table 4 - Cash Pending" + Confirm button

**Card:**

- Checks if card already added via settings
  - If yes → shows saved card (session-only, not persisted) with option to pay
  - If no → shows guest card entry form
- One-time gateway transaction
- On success → Thank You screen

**Online:**

- Shows QR code / payment link
- On confirmed → Thank You screen

**cash_waiting_screen.dart ← NEW**

**Purpose:** Locked screen while waiting for staff to confirm cash.

- "Please call your waiter to complete payment" message
- Gentle animation
- Customer cannot navigate away or add more items
- Listens to WebSocket for payment_confirmed event
- On event received → navigates to Thank You screen

**thankyou_reset_screen.dart ← NEW**

**Purpose:** Post-payment confirmation and session reset.

- "Thank you for dining with us!" message
- 5-second countdown
- On countdown end:
  - JWT cleared from device
  - Any card details wiped from memory
  - Session state cleared
  - Navigate back to TablePinScreen
- Table status → cleaning (backend)

**dinein_settings_screen.dart ← NEW**

**Purpose:** Minimal settings for kiosk session - no profile editing, no address.

**What's included:**

- Add / view card for this session (stored in memory only, never persisted to DB)
- Language preference (if multilingual support exists)
- Call Waiter button (sends notification to kitchen dashboard)

**What's explicitly removed vs customer app:**

- ❌ Edit profile (name, email, phone)
- ❌ Change delivery address
- ❌ Notification preferences
- ❌ Account deletion
- ❌ Order history beyond current session

Card added here is held in SessionState memory only:

dart

**class** SessionState {

**static** CardDetails? sessionCard; _// wiped on ThankYouResetScreen_

_// ..._

}

**Phase 5 - Admin Dashboard Additions**

**Table Manager**

- Create table → enter table number → backend generates PIN → display once for staff
- Regenerate PIN → old PIN immediately invalidated
- Delete table → only when available

**Live Table Status Board**

Real-time grid of all tables:

| **Status**            | **Indicator** | **Meaning**            |
| --------------------- | ------------- | ---------------------- |
| Available             | 🟢 Green      | Empty, ready           |
| Occupied              | 🟡 Yellow     | Active session         |
| Bill Requested (Cash) | 🟠 Orange     | Awaiting staff confirm |
| Bill Requested (Card) | 🔵 Blue       | Payment processing     |
| Cleaning              | ⚫ Grey       | Paid, not yet cleaned  |

**Active Session Detail**

Click any occupied table → side panel:

- Session start time + duration
- All order rounds with items and timestamps
- Running total
- "Confirm Cash Received" button (only for bill_requested_cash)

**Session History**

- All closed sessions per table
- Date, duration, total, payment method
- Revenue per table analytics

**Phase 6 - Kitchen Dashboard Additions**

**Changes to kitchen/kitchen_dashboard.py:**

**Order Card Updates**

Every dine-in order card tagged with table context:

text

┌──────────────────────────────┐

│ TABLE 4 • Round 2 • Dine-In │

│ 9:15 PM │

├──────────────────────────────┤

│ • Pepsi × 2 │

│ • Garlic Bread × 1 │

└──────────────────────────────┘

**Table Status Panel (new sidebar in Streamlit)**

- Live grid of all tables with color-coded status
- "Confirm Cash Received" button → appears only for bill_requested_cash tables
- "Mark Table Ready" button → appears only for cleaning tables
- Real-time updates via WebSocket subscription

**Complete Dine-In Flow (End to End)**

text

SETUP (Admin, one time per table)

Admin creates table in dashboard

→ Enters table number (e.g. "T4")

→ Backend generates 6-digit PIN (e.g. "482916")

→ Staff notes PIN, enters it on tablet

SESSION START

Staff enters table_number + PIN on kiosk app

→ POST /auth/table-login validates

→ dine_in_session created

→ JWT: type=dine_in, session_id, table_id, table_number

→ Table status → occupied

→ Kitchen + admin dashboards update live

→ Kiosk navigates to DineIn Home Screen

HOME SCREEN

Customer sees:

→ Custom Deal banner (top)

→ Top Sellers / Liked by Customers (below)

→ Bottom nav: Home | Menu | Deals | Orders

ORDERING (can repeat multiple times)

Customer browses Menu / Deals

→ Adds items to cart (same cart UI as customer app)

→ Reviews cart (same cart screen)

→ Taps "Send to Kitchen" (instead of "Proceed to Checkout")

→ POST /dine-in/order fires to kitchen directly

→ Kitchen sees: "Table 4 - Round 1 - \[items\]"

→ Cart clears, navigates to Order History

→ Order history shows Round 1 with status "To Be Paid"

→ Customer can return to home, order Round 2, 3...

ORDER TRACKING

Customer taps any order round

→ Order tracking screen shows kitchen preparation status

→ Same real-time tracking as delivery orders

READY TO PAY

Customer taps "Request Bill" from Order History

→ Full session summary shown (all rounds, total)

→ Payment method selection screen

── CASH ──────────────────────────────────────────

Customer selects Cash

→ Session → payment_pending_cash

→ CashWaitingScreen: locked, "Call your waiter"

→ Kitchen dashboard: "Table 4 - Cash Pending" + Confirm

→ Staff collects cash, taps Confirm

→ WebSocket: payment_confirmed → tablet

→ All orders marked paid

→ Thank You screen (5s) → PIN screen

── CARD ──────────────────────────────────────────

Customer selects Card

→ If card added via settings: use it

→ If not: guest card entry form

→ One-time gateway transaction (no storage)

→ On success → Thank You screen (5s) → PIN screen

── ONLINE ────────────────────────────────────────

Customer selects Online

→ QR / payment link shown

→ On confirmed → Thank You screen (5s) → PIN screen

── ALL PATHS ─────────────────────────────────────

Thank You Screen

→ Session closed in DB

→ Table → cleaning

→ JWT + card details + session state wiped from device

→ 5s countdown → back to PIN screen

Staff cleans table

→ Taps "Mark Table Ready" on kitchen/admin dashboard

→ Table → available

→ Ready for next customer

**Security Considerations**

| **Concern**                                   | **Mitigation**                                                                                          |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| Kiosk app accessible to public                | com.khadim.restaurant published as restricted Play Store listing - not publicly searchable              |
| PIN brute force                               | Rate limit /auth/table-login: 5 attempts per minute per table                                           |
| Card details stored                           | Never persisted - held in SessionState memory only, wiped on ThankYouResetScreen                        |
| Ghost sessions (tablet crash)                 | Sessions older than 6 hours auto-expire via backend cron job                                            |
| Cash confirm abused                           | confirm-cash endpoint requires staff/admin JWT - tablet JWT cannot call it                              |
| Customer adds more items after bill requested | Frontend locks navigation on CashWaitingScreen; backend rejects new orders for payment_pending sessions |

**File Structure Summary**

text

App/

├── lib/

│ ├── main.dart ← untouched (customer app)

│ ├── main_kiosk.dart ← NEW (kiosk entry point)

│ ├── app_config.dart ← NEW (flavor config)

│ ├── services/

│ │ └── dine_in_service.dart ← NEW

│ └── screens/

│ ├── dine_in/ ← NEW

│ │ ├── table_pin_screen.dart

│ │ ├── dinein_home_screen.dart

│ │ ├── dinein_order_history_screen.dart

│ │ ├── dine_in_payment_screen.dart

│ │ ├── cash_waiting_screen.dart

│ │ ├── thankyou_reset_screen.dart

│ │ └── dinein_settings_screen.dart

│ ├── menu/

│ │ └── menu_screen.dart ← shared, one conditional added

│ ├── cart/

│ │ └── cart_screen.dart ← shared, confirm action conditional

│ └── orders/

│ └── order_tracking_screen.dart ← shared, unchanged

└── android/app/

├── build.gradle ← modified: productFlavors

└── src/

├── customer/res/mipmap-\*/ ← Khadim icon

└── kiosk/res/mipmap-\*/ ← Khadim Restaurant icon

backend/

├── auth/

│ └── auth_routes.py ← modified: /auth/table-login added

├── dine_in/ ← NEW module

│ ├── \__init_\_.py

│ ├── dine_in_routes.py

│ └── websocket_manager.py

├── admin/

│ └── table_routes.py ← NEW

├── kitchen/

│ ├── kitchen_agent.py ← modified: table context on orders

│ └── kitchen_dashboard.py ← modified: table panel + action buttons

├── orders/

│ └── order_routes.py ← modified: skip address for dine_in

├── cart/

│ └── cart_routes.py ← modified: dine_in confirm path

└── main.py ← modified: new routers + WS endpoints

**Estimated Implementation Timeline**

| **Phase** | **Task**                                          | **Effort**   |
| --------- | ------------------------------------------------- | ------------ |
| 1         | Flutter flavor setup                              | 0.5 day      |
| 2         | Database changes                                  | 0.5 day      |
| 3         | Backend - PIN login + dine-in routes              | 2 days       |
| 3         | Backend - WebSocket manager                       | 1 day        |
| 3         | Backend - admin table routes                      | 1 day        |
| 3         | Kitchen dashboard additions                       | 1 day        |
| 4         | Flutter - 7 new kiosk screens                     | 3 days       |
| 4         | Flutter - shared screen conditionals (cart, menu) | 0.5 day      |
| 4         | Flutter - dine-in service + WebSocket listener    | 0.5 day      |
| 5         | Admin dashboard - Table Manager + Status Board    | 1.5 days     |
| 6         | End-to-end testing (all 3 payment paths)          | 1 day        |
| -         | **Total**                                         | **~12 days** |

**Production Upgrade Path (Post-FYP)**

This implementation is production-ready as-is. Future hardening when deploying commercially:

- Replace PIN with **QR code scanning** on tablet boot for higher-turnover restaurants
- Add **iOS flavor** for iPad support
- Move WebSocket to **Redis Pub/Sub** for multi-server scalability
- Add **offline resilience** - tablet caches orders locally on connectivity loss, syncs on reconnect
- Add a **lightweight waiter app** (third flavor) for staff mobile devices showing table alerts and confirm actions

**Document prepared by:** Perplexity AI Assistant  
**For:** Ahmed Naveed - Khadim FYP, FAST-NUCES Islamabad  
**Supervisor:** Dr. Akhtar Jamil | **Co-Supervisor:** Mr. Usama Imtiaz