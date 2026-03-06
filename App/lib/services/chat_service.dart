import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'token_storage.dart';

class ChatService {
  static String get _base => ApiConfig.baseUrl;

  static const Duration timeout = Duration(seconds: 25);

  Future<Map<String, dynamic>> sendTextMessage(
      String sessionId,
      String text,
      String lang,
      ) async {
    final token = await TokenStorage.getToken();
    final uri = Uri.parse("$_base/chat/text");

    final res = await http
        .post(
      uri,
      headers: {
        "Content-Type": "application/json",
        if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "session_id": sessionId,
        "text": text,
        "lang": lang,
      }),
    )
        .timeout(timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Chat text failed: ${res.statusCode} ${res.body}");
    }

    final decoded = jsonDecode(res.body);
    return (decoded is Map<String, dynamic>) ? decoded : {"reply": ""};
  }

  Future<Map<String, dynamic>> sendVoiceMessage(
      String sessionId,
      File audioFile,
      String mode,
      String lang,
      ) async {
    final token = await TokenStorage.getToken();
    final uri = Uri.parse("$_base/chat/voice");

    final req = http.MultipartRequest("POST", uri);

    if (token != null && token.isNotEmpty) {
      req.headers["Authorization"] = "Bearer $token";
    }

    req.fields["session_id"] = sessionId;
    req.fields["mode"] = mode; // "voice" in your call
    req.fields["lang"] = lang; // "en"
    req.files.add(await http.MultipartFile.fromPath("file", audioFile.path));

    final streamed = await req.send().timeout(timeout);
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception("Chat voice failed: ${streamed.statusCode} $body");
    }

    final decoded = jsonDecode(body);
    return (decoded is Map<String, dynamic>) ? decoded : {"transcript": "", "reply": ""};
  }
}