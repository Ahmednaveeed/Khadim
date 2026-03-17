import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_headers.dart';

class FeedbackService {
  /// Submit general / regular order feedback (existing endpoint).
  static Future<Map<String, dynamic>> submitFeedback({
    required int rating,
    required String message,
    int? orderId,
    String feedbackType = 'ORDER',
  }) async {
    final headers = await AuthHeaders.getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/feedback');

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({
        'rating': rating,
        'message': message,
        'order_id': orderId,
        'feedback_type': feedbackType,
      }),
    );

    return _handleResponse(response);
  }

  /// Submit custom deal feedback (new endpoint).
  ///
  /// [itemRatings] is a list of {item_id, rating} maps for individual items
  /// the user chose to rate.
  static Future<Map<String, dynamic>> submitCustomDealFeedback({
    required int orderId,
    required int customDealId,
    required int overallRating,
    required String message,
    List<Map<String, int>> itemRatings = const [],
  }) async {
    final headers = await AuthHeaders.getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/feedback/custom-deal');

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({
        'order_id': orderId,
        'custom_deal_id': customDealId,
        'overall_rating': overallRating,
        'message': message,
        'item_ratings': itemRatings,
      }),
    );

    return _handleResponse(response);
  }

  /// Fetch items inside a custom deal (for the per-item rating UI).
  static Future<Map<String, dynamic>> getCustomDealItems(int customDealId) async {
    final headers = await AuthHeaders.getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/custom-deal/$customDealId');

    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  // ── Shared response handler ──────────────────────────────────────────
  static Map<String, dynamic> _handleResponse(http.Response response) {
    final dynamic decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : {};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    }

    String errorMessage = 'Request failed';
    if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
      errorMessage = decoded['detail'].toString();
    }
    throw Exception(errorMessage);
  }
}