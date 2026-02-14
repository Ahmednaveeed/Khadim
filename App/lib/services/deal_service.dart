import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/deal_model.dart';
import 'api_config.dart';

class DealService {
  static String baseUrl = ApiConfig.baseUrl;

  static Future<List<DealModel>> fetchDeals() async {
    final response = await http.get(Uri.parse("$baseUrl/deals"));

    if (response.statusCode != 200) {
      throw Exception("Failed to load deals");
    }

    final data = jsonDecode(response.body)["deals"];
    return List<DealModel>.from(data.map((e) => DealModel.fromJson(e)));
  }
}
