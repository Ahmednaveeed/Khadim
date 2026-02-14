import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/menu_item.dart';
import 'api_config.dart';

class MenuService {
  static String baseUrl = ApiConfig.baseUrl;

  static Future<List<MenuItemModel>> fetchMenu() async {
    final response = await http.get(Uri.parse("$baseUrl/menu"));

    if (response.statusCode != 200) {
      throw Exception("Failed to load menu");
    }

    final body = jsonDecode(response.body);
    final List items = body["menu"];

    return items.map((e) => MenuItemModel.fromJson(e)).toList();
  }
}
