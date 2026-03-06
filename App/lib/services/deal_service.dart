import '../models/deal_model.dart';
import 'api_client.dart';

class DealService {
  static Future<List<DealModel>> fetchDeals() async {
    final res = await ApiClient.getJson("/deals", auth: true);

    // backend returns: { "deals": [...] }
    final list = (res["deals"] ?? []) as List;
    return list.map((e) => DealModel.fromJson(e)).toList();
  }
}