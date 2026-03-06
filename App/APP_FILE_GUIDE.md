# Flutter App File Guide

This document explains what each folder and file does in the Flutter app project.

---

## Root Folder

- **README.md**: Main project setup/readme for the Flutter app.
- **pubspec.yaml**: Flutter dependencies, assets, and project metadata.
- **pubspec.lock**: Exact resolved dependency versions.
- **analysis_options.yaml**: Dart linting and analyzer rules.

Platform/runtime folders:
- **android/**: Android project files and Gradle configuration.
- **ios/**: iOS project files and Xcode configuration.
- **web/**: Flutter web runner files.
- **test/**: Widget/unit tests (if added).

Generated/build folders:
- **.dart_tool/**, **build/**, **.idea/** and metadata files.

---

## lib/

Main Dart source code for app logic, UI, and API integration.

- **main.dart**: App entrypoint. Registers `CartProvider`, theme setup, named routes, and splash as initial route.

---

## lib/models/

Data models used by API responses and UI state.

- **auth_user.dart**: Authenticated user model (`user_id`, name, email/phone).
- **cart_item.dart**: Local/UI cart item model with quantity and item type.
- **menu_item.dart**: Menu item model from `/menu` API.
- **deal_model.dart**: Deal model from `/deals` API.
- **offer_model.dart**: Offer model from `/offers` API.
- **order.dart**: Order aggregate model (number, amount, address, item list).
- **orderitem.dart**: Individual line item model inside an order.
- **payment_method.dart**: Payment method DTO used by payment screens.

---

## lib/providers/

State management (Provider package).

- **cart_provider.dart**: Single source of cart UI state. Handles cart init, backend sync, add/update/remove actions, totals, error/loading flags.

---

## lib/services/

Backend communication, auth/session storage, and utility services.

- **api_config.dart**: Base API URL for backend connection.
- **api_client.dart**: Shared HTTP client wrapper (timeouts, retries for GET, error normalization, auth header integration).
- **auth_headers.dart**: Header builders (basic + bearer token).
- **token_storage.dart**: Secure storage for JWT token.
- **cart_storage.dart**: Secure storage for active cart ID.
- **auth_service.dart**: Auth API methods (`signup`, `login`, `me`).
- **menu_service.dart**: Fetch menu data.
- **deal_service.dart**: Fetch deals data.
- **offer_service.dart**: Fetch offers data.
- **cart_service.dart**: Cart APIs (`/cart/active`, summary, add item, set qty, remove, place order).
- **chat_service.dart**: Text/voice chat requests and multipart upload handling.
- **payment_service.dart**: In-memory payment methods store (currently local/mock, not backend persisted).

---

## lib/screens/

UI screens grouped by feature domain.

### auth/
- **splash_screen.dart**: Startup loader and session bootstrap trigger.
- **login_screen.dart**: Login form, token save, session bootstrap.
- **signup_screen.dart**: Signup form, token save, session bootstrap.

### navigation/
- **main_screen.dart**: Bottom navigation host (Home/Menu/Offers/Profile), floating mic button, cart shortcut.

### discover/
- **home_screen.dart**: Deal discovery list and add-deal-to-cart actions.
- **offer_screen.dart**: Promotional offers + deals list with banner carousel.

### menu/
- **menu_screen.dart**: Menu listing with search/filter chips and add-to-cart for menu items.

### cart/
- **cart_screen.dart**: Cart review, quantity editing, totals, and checkout navigation.

### checkout/
- **checkout_screen.dart**: Address + payment selection + order place action via backend cart API.

### payments/
- **payment_method_screen.dart**: View/manage payment methods UI.
- **add_payment_screen.dart**: Add new card/payment form UI.

### orders/
- **order_confirmation_screen.dart**: Post-checkout success screen.
- **order_tracking_screen.dart**: Tracking UI (currently static/mock progression).
- **order_history_screen.dart**: History UI (currently mostly dummy data + optional latest order injection).

### chat/
- **chat_bottom_sheet.dart**: Voice/text chat panel, recording, send requests, and TTS playback.

### profile/
- **profile_screen.dart**: Profile hub linking to personal info, history, favorites, settings.
- **personal_info_screen.dart**: Personal details and payment methods shortcut.
- **settings_screen.dart**: Notification/support/account options (mostly local/UI actions).

### support/
- **favorites_screen.dart**: Favorites UI.
- **feedback_screen.dart**: Feedback UI.
- **notifications_screen.dart**: Notifications UI.

### devtools/
- **test_urdu_tts.dart**: Developer test page for Urdu text-to-speech behavior.

---

## lib/themes/

- **app_theme.dart**: App-wide light/dark theme definitions (colors, typography, component styling).

---

## lib/utils/

- **app_images.dart**: Central constants for asset image paths.
- **ImageResolver.dart**: Maps cuisine/deal names to fallback local asset images.
- **session_bootstrap.dart**: Session bootstrap flow (token check -> `/auth/me` -> cart init -> route decision).

---

## lib/widgets/

- Currently empty. Reserved for reusable shared UI widgets.

---

## End-to-End App Workflow (Current)

1. App starts at `SplashScreen`.
2. `SessionBootstrap` checks secure token.
3. If token missing/invalid -> go to login.
4. If token valid -> call `/auth/me`, init cart, go to main screen.
5. User browses Menu/Deals/Offers and adds items to cart (backend synced).
6. Cart screen updates/removes quantities via backend APIs.
7. Checkout places order from active cart and navigates to confirmation.
8. Chat bottom sheet allows text/voice assistant calls.

---

## Backend Integration Status Snapshot

Fully backend-connected now:
- Auth (`signup`, `login`, `me`)
- Menu, Deals, Offers fetch
- Cart lifecycle (`active`, summary, add/update/remove, place order)

Partially/local-only right now:
- Payment methods (local in-memory list)
- Order history/tracking data (mostly static/demo)
- Some profile/settings actions are UI placeholders

---

## Important Notes for Developers

- Keep `api_config.dart` base URL aligned with your backend host/port.
- Chat service endpoint paths should match backend routes exactly.
- `CartProvider` is the key state layer; feature changes touching cart should pass through provider methods.
- `session_bootstrap.dart` controls login-vs-main routing logic and is the first place to check for startup auth issues.

---

## Suggested Reading Order for New Developers

1. `lib/main.dart`
2. `lib/utils/session_bootstrap.dart`
3. `lib/services/api_client.dart` and `lib/services/api_config.dart`
4. `lib/providers/cart_provider.dart`
5. `lib/screens/navigation/main_screen.dart`
6. Feature screens: menu -> cart -> checkout -> orders
7. `lib/screens/chat/chat_bottom_sheet.dart` and `lib/services/chat_service.dart`
