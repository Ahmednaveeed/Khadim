import '../models/offer_model.dart';
import 'api_client.dart';

class OfferService {
  static Future<List<OfferModel>> fetchOffers() async {
    final res = await ApiClient.getJson("/offers", auth: true);

    // If backend returns a raw list, ApiClient wraps it as {"data": [...]}
    final data = (res["data"] ?? res["offers"] ?? []) as List;

    return data.map((e) => OfferModel.fromJson(e)).toList();
  }
}