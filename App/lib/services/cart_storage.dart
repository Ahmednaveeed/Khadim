import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CartStorage {
  static const _storage = FlutterSecureStorage();
  static const _key = 'active_cart_id';

  static Future<void> saveCartId(String cartId) async {
    await _storage.write(key: _key, value: cartId);
  }

  static Future<String?> getCartId() async {
    return _storage.read(key: _key);
  }

  static Future<void> clearCartId() async {
    await _storage.delete(key: _key);
  }
}