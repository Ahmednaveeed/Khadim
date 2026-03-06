import '../models/menu_item.dart';
import 'api_client.dart';

class MenuService {
  static Future<List<MenuItemModel>> fetchMenu() async {
    final res = await ApiClient.getJson("/menu", auth: true);

    final data = res["data"] ?? res;
    final list = (data["menu"] ?? []) as List;

    return list.map((e) => MenuItemModel.fromJson(e)).toList();
  }
}