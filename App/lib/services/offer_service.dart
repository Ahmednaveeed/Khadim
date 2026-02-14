import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/offer_model.dart';
import 'api_config.dart';

class OfferService {
  static String baseUrl = ApiConfig.baseUrl;

  static Future<List<OfferModel>> fetchOffers() async {
    final response = await http.get(Uri.parse("$baseUrl/offers"));

    if (response.statusCode != 200) {
      throw Exception("Failed to load offers");
    }

    final List data = jsonDecode(response.body);
    return data.map((e) => OfferModel.fromJson(e)).toList();
  }
}
