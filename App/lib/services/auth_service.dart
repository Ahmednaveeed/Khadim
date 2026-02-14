import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class AuthService {
  static Future<Map<String, dynamic>> signup({
    required String fullName,
    String? email,
    String? phone,
    required String password,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/auth/signup');

    final body = {
      'full_name': fullName,
      'email': (email != null && email.trim().isNotEmpty) ? email.trim() : null,
      'phone': (phone != null && phone.trim().isNotEmpty) ? phone.trim() : null,
      'password': password,
    };

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } else {
      throw Exception(_extractError(res.body));
    }
  }

  static Future<Map<String, dynamic>> login({
    required String identifier, // email or phone
    required String password,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/auth/login');

    final body = {
      'identifier': identifier.trim(),
      'password': password,
    };

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } else {
      throw Exception(_extractError(res.body));
    }
  }

  static Future<Map<String, dynamic>> me({required String token}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/auth/me');

    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } else {
      throw Exception(_extractError(res.body));
    }
  }

  static String _extractError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null) return decoded['detail'].toString();
      return body;
    } catch (_) {
      return body;
    }
  }
}