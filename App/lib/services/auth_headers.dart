import 'token_storage.dart';

class AuthHeaders {
  static Future<Map<String, String>> basic({bool json = true}) async {
    final headers = <String, String>{
      "Accept": "application/json",
    };

    if (json) {
      headers["Content-Type"] = "application/json";
    }

    return headers;
  }

  static Future<Map<String, String>> withAuth({bool json = true}) async {
    final token = await TokenStorage.getToken();

    final headers = <String, String>{
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    if (json) {
      headers["Content-Type"] = "application/json";
    }

    return headers;
  }

  // Backwards compatible for existing code (your ChatService calls this)
  static Future<Map<String, String>> getHeaders({bool json = true}) async {
    return withAuth(json: json);
  }
}