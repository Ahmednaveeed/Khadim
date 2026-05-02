import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists dine-in session fields and (for kiosk) the table PIN so guests
/// never re-enter the PIN after payment — only the active session row is cleared.
class DineInSessionStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _sessionIdKey = 'dine_in_session_id';
  static const String _tableIdKey = 'dine_in_table_id';
  static const String _tableNumberKey = 'dine_in_table_number';
  static const String _tokenKey = 'dine_in_token';
  static const String _startedAtKey = 'dine_in_started_at';
  static const String _tablePinKey = 'dine_in_kiosk_table_pin';

  static Future<void> saveSession({
    required String sessionId,
    required String tableId,
    required String tableNumber,
    String? token,
    DateTime? startedAt,
  }) async {
    await _storage.write(key: _sessionIdKey, value: sessionId);
    await _storage.write(key: _tableIdKey, value: tableId);
    await _storage.write(key: _tableNumberKey, value: tableNumber);
    if (startedAt != null) {
      await _storage.write(
        key: _startedAtKey,
        value: startedAt.toIso8601String(),
      );
    } else {
      await _storage.delete(key: _startedAtKey);
    }
    if (token != null && token.isNotEmpty) {
      await _storage.write(key: _tokenKey, value: token);
    } else {
      await _storage.delete(key: _tokenKey);
    }
  }

  /// Persists the kiosk table PIN (6 digits). Call when the guest enters PIN.
  static Future<void> saveTablePin(String pin) async {
    final t = pin.trim();
    if (t.isEmpty) {
      await _storage.delete(key: _tablePinKey);
    } else {
      await _storage.write(key: _tablePinKey, value: t);
    }
  }

  /// Clears only the active session (tokens, times). Keeps table id/number and
  /// PIN so the kiosk can call [table-start-session] without PIN re-entry.
  static Future<void> clearActiveSessionOnly() async {
    await _storage.delete(key: _sessionIdKey);
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _startedAtKey);
  }

  /// Full wipe (e.g. true logout / admin reset).
  static Future<void> clearAll() async {
    await _storage.delete(key: _sessionIdKey);
    await _storage.delete(key: _tableIdKey);
    await _storage.delete(key: _tableNumberKey);
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _startedAtKey);
    await _storage.delete(key: _tablePinKey);
  }

  /// Backward-compatible alias for [clearAll].
  static Future<void> clearSession() async => clearAll();

  /// Returns stored session + table lock. Present if [table_id] and
  /// [table_number] exist — [session_id] may be empty after payment end.
  static Future<Map<String, String>?> getSession() async {
    final sessionId = await _storage.read(key: _sessionIdKey);
    final tableId = await _storage.read(key: _tableIdKey);
    final tableNumber = await _storage.read(key: _tableNumberKey);
    final token = await _storage.read(key: _tokenKey);
    final startedAt = await _storage.read(key: _startedAtKey);
    final tablePin = await _storage.read(key: _tablePinKey);

    if (tableId == null ||
        tableId.isEmpty ||
        tableNumber == null ||
        tableNumber.isEmpty) {
      return null;
    }

    return {
      'session_id': sessionId ?? '',
      'table_id': tableId,
      'table_number': tableNumber,
      'token': token ?? '',
      'started_at': startedAt ?? '',
      'table_pin': tablePin ?? '',
    };
  }
}
