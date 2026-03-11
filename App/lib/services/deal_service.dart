import '../models/deal_model.dart';
import 'api_client.dart';

class DealService {
  static Future<List<DealModel>> fetchDeals() async {
    final res = await ApiClient.getJson("/deals", auth: true);

    // backend returns: { "deals": [...] }
    final list = (res["deals"] ?? []) as List;
    return list.map((e) => DealModel.fromJson(e)).toList();
  }

  /// Create a custom deal using natural language query
  /// Returns: {success: bool, message: String, deal_data: {...}}
  static Future<Map<String, dynamic>> createCustomDeal(String query) async {
    final res = await ApiClient.postJson(
      "/deals/custom",
      body: {"query": query},
      auth: true,
      timeout: const Duration(seconds: 30), // LLM calls may take longer
    );
    return res;
  }
}