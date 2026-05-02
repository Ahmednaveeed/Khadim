import 'dart:async';

import 'package:flutter/material.dart';
import 'package:khaadim/services/dine_in_service.dart';
import 'package:khaadim/services/dine_in_session_storage.dart';

/// UI-facing state of the "Call Waiter" workflow.
///
/// Shared by both the manual button on `MyTableScreen` and the voice-command
/// pipeline so either entry-point produces the same visual feedback.
enum WaiterRequestState { idle, notified, acknowledged }

class CardDetails {
  final String cardNumber;
  final String expiry;
  final String cvv;

  CardDetails({
    required this.cardNumber,
    required this.expiry,
    required this.cvv,
  });
}

class DineInProvider extends ChangeNotifier {
  String? sessionId;
  String? tableNumber;
  String? tableId;
  String? token;
  DateTime? startedAt;
  CardDetails? sessionCard;
  String? _cachedTableNumber;
  String? _cachedTablePin;
  List<Map<String, dynamic>> currentOrderItems = [];
  bool isLoading = false;

  // ── Waiter-call shared state ─────────────────────────────────────────────
  // Both the manual "CALL WAITER" button and the voice-command handler drive
  // the same state machine here so the banner / polling / auto-reset work
  // identically regardless of how the call was initiated.
  WaiterRequestState _waiterRequestState = WaiterRequestState.idle;
  String? _activeWaiterCallId;
  Timer? _waiterStatusPoller;
  Timer? _waiterAckResetTimer;
  final DineInService _waiterService = DineInService();

  WaiterRequestState get waiterRequestState => _waiterRequestState;
  String? get activeWaiterCallId => _activeWaiterCallId;
  bool get isWaiterRequestPending =>
      _waiterRequestState != WaiterRequestState.idle;

  // ── Voice-payment disambiguation ─────────────────────────────────────────
  // When the guest says "mujhe payment karni hai" without specifying the
  // method, the voice service asks "card ya cash?" and sets this flag.
  // The next inbound utterance that mentions a method is routed straight
  // to the matching handler. Consumers must call [clearAwaitingPaymentMethod]
  // after consuming it.
  bool _awaitingPaymentMethod = false;
  bool get awaitingPaymentMethod => _awaitingPaymentMethod;

  void setAwaitingPaymentMethod() {
    if (_awaitingPaymentMethod) return;
    _awaitingPaymentMethod = true;
    notifyListeners();
  }

  void clearAwaitingPaymentMethod() {
    if (!_awaitingPaymentMethod) return;
    _awaitingPaymentMethod = false;
    notifyListeners();
  }

  String? get cachedTableNumber => _cachedTableNumber;
  String? get cachedTablePin => _cachedTablePin;
  bool get hasCachedTableCredentials {
    return (_cachedTableNumber ?? '').trim().isNotEmpty &&
        (_cachedTablePin ?? '').trim().isNotEmpty;
  }

  void cacheTableCredentials(String tableNumber, String pin) {
    _cachedTableNumber = tableNumber.trim();
    _cachedTablePin = pin.trim();
    unawaited(DineInSessionStorage.saveTablePin(_cachedTablePin ?? ''));
  }

  void clearCachedTableCredentials() {
    _cachedTableNumber = null;
    _cachedTablePin = null;
  }

  void loginTable(
    String tableId,
    String tableNumber, {
    String? sessionId,
    String? token,
    DateTime? startedAt,
  }) {
    this.sessionId = sessionId;
    this.tableId = tableId;
    this.tableNumber = tableNumber;
    this.token = token;
    this.startedAt = startedAt;
    sessionCard = null;
    currentOrderItems.clear();
    unawaited(
      _persistSession(sessionId, tableId, tableNumber, token, this.startedAt),
    );
    notifyListeners();
  }

  void applySession(String sessionId, DateTime startedAt) {
    this.sessionId = sessionId;
    this.startedAt = startedAt;
    if (tableId != null && tableNumber != null) {
      unawaited(
        _persistSession(sessionId, tableId!, tableNumber!, token, startedAt),
      );
    }
    notifyListeners();
  }

  Future<void> _persistSession(
    String? sessionId,
    String tableId,
    String tableNumber,
    String? token,
    DateTime? startedAt,
  ) async {
    try {
      await DineInSessionStorage.saveSession(
        sessionId: sessionId ?? '',
        tableId: tableId,
        tableNumber: tableNumber,
        token: token,
        startedAt: startedAt,
      );
    } catch (_) {
      // Ignore persistence errors and keep in-memory session active.
    }
  }

  Future<bool> restoreSession() async {
    final saved = await DineInSessionStorage.getSession();
    if (saved == null) {
      return false;
    }

    // It is perfectly correct to be logged in and waiting (sessionId == null).
    sessionId = saved['session_id'];
    if (sessionId != null && sessionId!.isEmpty) {
      sessionId = null;
    }

    tableId = saved['table_id'];
    tableNumber = saved['table_number'];
    final restoredToken = saved['token'];
    final restoredStartedAt = saved['started_at'];
    token = (restoredToken == null || restoredToken.isEmpty)
        ? null
        : restoredToken;
    startedAt = restoredStartedAt == null || restoredStartedAt.isEmpty
        ? null
        : DateTime.tryParse(restoredStartedAt);
    sessionCard = null;
    currentOrderItems.clear();

    final pin = (saved['table_pin'] ?? '').trim();
    if (pin.isNotEmpty &&
        tableNumber != null &&
        tableNumber!.trim().isNotEmpty) {
      _cachedTableNumber = tableNumber!.trim();
      _cachedTablePin = pin;
    }

    notifyListeners();

    // The user is authenticated securely to the Table. Bypasses the Lock Screen.
    return tableId != null && tableId!.isNotEmpty;
  }

  void addItem(
    int itemId,
    String itemType,
    String itemName,
    double price,
    int quantity,
  ) {
    final index = currentOrderItems.indexWhere(
      (item) => item['item_id'] == itemId && item['item_type'] == itemType,
    );

    if (index >= 0) {
      final existingQuantity =
          (currentOrderItems[index]['quantity'] as num?)?.toInt() ?? 0;
      currentOrderItems[index]['quantity'] = existingQuantity + quantity;
      currentOrderItems[index]['item_name'] = itemName;
      currentOrderItems[index]['price'] = price;
    } else {
      currentOrderItems.add({
        'item_id': itemId,
        'item_type': itemType,
        'item_name': itemName,
        'price': price,
        'quantity': quantity,
      });
    }

    notifyListeners();
  }

  void addCustomDeal({
    required int customDealId,
    required String title,
    required double totalPrice,
    required int groupSize,
    required List<Map<String, dynamic>> bundleItems,
  }) {
    final normalizedBundle = bundleItems
        .map((raw) {
          final rawType = (raw['item_type'] ?? 'menu_item').toString();
          final normalizedType = rawType == 'deal' ? 'deal' : 'menu_item';
          final rawId = raw['item_id'];
          final rawQuantity = raw['quantity'];
          final rawPrice =
              raw['price'] ?? raw['item_price'] ?? raw['unit_price'];

          return {
            'item_id': rawId is int
                ? rawId
                : int.tryParse(rawId.toString()) ?? 0,
            'item_type': normalizedType,
            'item_name': (raw['item_name'] ?? 'Item').toString(),
            'quantity': rawQuantity is int
                ? rawQuantity
                : int.tryParse(rawQuantity.toString()) ?? 1,
            'price': rawPrice is num
                ? rawPrice.toDouble()
                : double.tryParse(rawPrice.toString()) ?? 0.0,
          };
        })
        .where(
          (item) =>
              (item['item_id'] as int) > 0 && (item['quantity'] as int) > 0,
        )
        .toList();

    currentOrderItems.add({
      'item_id': customDealId,
      'item_type': 'custom_deal',
      'item_name': title,
      'price': totalPrice,
      'quantity': 1,
      'group_size': groupSize,
      'is_quantity_locked': true,
      'bundle_items': normalizedBundle,
    });

    notifyListeners();
  }

  void removeItem(int itemId, String itemType) {
    currentOrderItems.removeWhere(
      (item) => item['item_id'] == itemId && item['item_type'] == itemType,
    );
    notifyListeners();
  }

  void clearOrder() {
    currentOrderItems.clear();
    notifyListeners();
  }

  void saveSessionCard(CardDetails card) {
    sessionCard = card;
    notifyListeners();
  }

  /// Clears the active dine-in session but keeps this kiosk locked to the same
  /// table (table id/number + PIN on disk) so guests never re-enter the PIN
  /// after payment or manual end — only "Start session" is needed.
  Future<void> clearSessionKeepTableLock() async {
    sessionId = null;
    token = null;
    startedAt = null;
    sessionCard = null;
    currentOrderItems.clear();
    isLoading = false;
    _resetWaiterStateInternal(notify: false);
    tableNumber = null;
    tableId = null;
    try {
      await DineInSessionStorage.clearActiveSessionOnly();
      await _syncTableIdentityFromStorage();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _syncTableIdentityFromStorage() async {
    final saved = await DineInSessionStorage.getSession();
    if (saved == null) return;
    final tid = saved['table_id'];
    final tnum = saved['table_number'];
    final pin = (saved['table_pin'] ?? '').trim();
    if (tid != null && tid.isNotEmpty) tableId = tid;
    if (tnum != null && tnum.isNotEmpty) tableNumber = tnum;
    if (pin.isNotEmpty && tnum != null && tnum.isNotEmpty) {
      _cachedTableNumber = tnum.trim();
      _cachedTablePin = pin;
    }
  }

  /// Loads table number + PIN from secure storage when in-memory cache is empty
  /// (e.g. rare timing edge). Safe to call before "Start session".
  Future<void> ensureTableCredentialsFromStorage() async {
    if (hasCachedTableCredentials) return;
    await _syncTableIdentityFromStorage();
    notifyListeners();
  }

  /// Same flow as after card payment / first PIN login: [tableLogin], and if
  /// the table has no active session yet (common right after payment), call
  /// [tableStartSession], then [loginTable] with ids + session so the full
  /// menu home appears — not just [applySession].
  Future<bool> loginOrStartSessionFromCache(DineInService service) async {
    await ensureTableCredentialsFromStorage();
    if (!hasCachedTableCredentials) return false;

    final num = _cachedTableNumber!.trim();
    final pin = _cachedTablePin!.trim();

    final loginResult = await service.tableLogin(num, pin);
    var sessionId = (loginResult['session_id'] ?? '').toString();
    final tableId = (loginResult['table_id'] ?? '').toString();
    var resolvedTableNumber =
        (loginResult['table_number'] ?? num).toString();
    final tok = (loginResult['token'] ?? loginResult['access_token'] ?? '')
        .toString();
    var startedAtRaw = (loginResult['started_at'] ?? '').toString();
    DateTime? startedAt =
        startedAtRaw.isEmpty ? null : DateTime.tryParse(startedAtRaw);

    if (tableId.isEmpty) return false;

    if (sessionId.isNotEmpty) {
      cacheTableCredentials(resolvedTableNumber, pin);
      loginTable(
        tableId,
        resolvedTableNumber,
        sessionId: sessionId,
        token: tok.isNotEmpty ? tok : null,
        startedAt: startedAt,
      );
      return true;
    }

    final startResult = await service.tableStartSession(num, pin);
    sessionId = (startResult['session_id'] ?? '').toString();
    final tableId2 = (startResult['table_id'] ?? '').toString();
    resolvedTableNumber =
        (startResult['table_number'] ?? resolvedTableNumber).toString();
    startedAtRaw = (startResult['started_at'] ?? '').toString();
    startedAt =
        startedAtRaw.isEmpty ? null : DateTime.tryParse(startedAtRaw);

    if (sessionId.isEmpty || tableId2.isEmpty) return false;

    cacheTableCredentials(resolvedTableNumber, pin);
    loginTable(
      tableId2,
      resolvedTableNumber,
      sessionId: sessionId,
      token: null,
      startedAt: startedAt,
    );
    return true;
  }

  double get orderTotal {
    return currentOrderItems.fold(0.0, (sum, item) {
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      return sum + (price * quantity);
    });
  }

  // ── Waiter-call API ──────────────────────────────────────────────────────

  /// Posts a waiter-call to the backend and flips the shared state to
  /// `notified`. Kicks off polling so the state advances to `acknowledged`
  /// once the kitchen dashboard resolves the call, after which it auto-resets
  /// to `idle` 5s later.
  ///
  /// Returns the raw backend response so callers (e.g. the cash-payment
  /// dialog) can read `call_id` / `message`. Throws on failure so callers can
  /// show a snackbar.
  Future<Map<String, dynamic>> notifyWaiter({
    bool forCashPayment = false,
  }) async {
    final activeSession = sessionId;
    if (activeSession == null || activeSession.isEmpty) {
      throw Exception('No active dine-in session found.');
    }

    final response = await _waiterService.callWaiter(
      activeSession,
      token: token,
      forCashPayment: forCashPayment,
    );

    final callId = response['call_id']?.toString();
    _waiterAckResetTimer?.cancel();
    _activeWaiterCallId = (callId != null && callId.isNotEmpty) ? callId : null;
    _waiterRequestState = WaiterRequestState.notified;
    notifyListeners();

    if (_activeWaiterCallId != null) {
      _startWaiterPolling();
    }

    return response;
  }

  /// Cancels in-flight polling / timers and returns the banner to idle.
  /// Safe to call from any code path (session logout, screen dispose, etc).
  void resetWaiterState() => _resetWaiterStateInternal(notify: true);

  void _resetWaiterStateInternal({required bool notify}) {
    _waiterStatusPoller?.cancel();
    _waiterStatusPoller = null;
    _waiterAckResetTimer?.cancel();
    _waiterAckResetTimer = null;
    final changed = _waiterRequestState != WaiterRequestState.idle ||
        _activeWaiterCallId != null;
    _waiterRequestState = WaiterRequestState.idle;
    _activeWaiterCallId = null;
    if (notify && changed) {
      notifyListeners();
    }
  }

  void _startWaiterPolling() {
    _waiterStatusPoller?.cancel();
    _waiterStatusPoller = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollWaiterCallStatus();
    });
  }

  Future<void> _pollWaiterCallStatus() async {
    final callId = _activeWaiterCallId;
    final activeSession = sessionId;
    if (callId == null || callId.isEmpty) {
      _waiterStatusPoller?.cancel();
      _waiterStatusPoller = null;
      return;
    }
    if (activeSession == null || activeSession.isEmpty) {
      _waiterStatusPoller?.cancel();
      _waiterStatusPoller = null;
      return;
    }

    try {
      final statusData = await _waiterService.fetchWaiterCallStatus(
        activeSession,
        callId,
        token: token,
      );

      final isResolved = statusData['resolved'] == true;
      if (!isResolved ||
          _waiterRequestState == WaiterRequestState.acknowledged) {
        return;
      }

      _waiterStatusPoller?.cancel();
      _waiterStatusPoller = null;
      _waiterRequestState = WaiterRequestState.acknowledged;
      notifyListeners();
      _scheduleWaiterAckReset();
    } catch (_) {
      // Swallow transient errors; the periodic timer will retry.
    }
  }

  void _scheduleWaiterAckReset() {
    _waiterAckResetTimer?.cancel();
    _waiterAckResetTimer = Timer(const Duration(seconds: 5), () {
      _resetWaiterStateInternal(notify: true);
    });
  }

  @override
  void dispose() {
    _waiterStatusPoller?.cancel();
    _waiterAckResetTimer?.cancel();
    super.dispose();
  }
}
