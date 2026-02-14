import '../services/token_storage.dart';

class AuthHeaders {
  static Future<Map<String, String>> getHeaders({bool json = true}) async {
    final token = await TokenStorage.getToken();

    final headers = <String, String>{};

    if (json) {
      headers['Content-Type'] = 'application/json';
    }

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }
}