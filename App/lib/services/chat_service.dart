import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_config.dart';
import 'auth_headers.dart';

class ChatService {
  final String baseUrl = ApiConfig.baseUrl;

  // -------------------------
  // TEXT MESSAGE
  // -------------------------
  Future<Map<String, dynamic>> sendTextMessage(
      String sessionId,
      String message,
      String language,
      ) async {

    final url = Uri.parse("$baseUrl/chat");

    final response = await http.post(
      url,
      headers: await AuthHeaders.getHeaders(),      body: jsonEncode({
        "session_id": sessionId,
        "message": message,
        "language": language,
      }),
    );

    return jsonDecode(response.body);
  }

  // -------------------------
  // VOICE MESSAGE
  // -------------------------
  Future<Map<String, dynamic>> sendVoiceMessage(
      String sessionId,
      File file,
      String selectedVoice,
      String language,
      ) async {

    final url = Uri.parse("$baseUrl/voice_chat");

    final request = http.MultipartRequest("POST", url);

    final headers = await AuthHeaders.getHeaders(json: false);
    request.headers.addAll(headers);

    request.fields["session_id"] = sessionId;
    request.fields["voice"] = selectedVoice;
    request.fields["language"] = language;

    request.files.add(
      await http.MultipartFile.fromPath(
        "file",
        file.path,
        contentType: MediaType("audio", "aac"),
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    return jsonDecode(response.body);
  }
}
