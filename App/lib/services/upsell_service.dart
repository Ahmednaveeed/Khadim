import 'api_client.dart';

class UpsellItem {
  final int itemId;
  final String itemName;
  final String? itemDescription;
  final double itemPrice;
  final String? itemCategory;

  UpsellItem({
    required this.itemId,
    required this.itemName,
    this.itemDescription,
    required this.itemPrice,
    this.itemCategory,
  });

  factory UpsellItem.fromJson(Map<String, dynamic> json) {
    return UpsellItem(
      itemId: json['item_id'] as int,
      itemName: json['item_name'] as String? ?? '',
      itemDescription: json['item_description'] as String?,
      itemPrice: double.tryParse(json['item_price']?.toString() ?? '0') ?? 0.0,
      itemCategory: json['item_category'] as String?,
    );
  }
}

class UpsellResult {
  final String headline;
  final String weatherCategory;
  final List<UpsellItem> items;

  UpsellResult({
    required this.headline,
    required this.weatherCategory,
    required this.items,
  });
}

class UpsellService {
  static Future<UpsellResult> fetchUpsell({String city = 'Islamabad'}) async {
    final res = await ApiClient.getJson(
      '/upsell?city=$city',
      auth: false,
    );

    final weather = res['weather'] as Map<String, dynamic>? ?? {};
    final headline = res['headline'] as String? ?? 'Recommended for you';
    final rawItems = res['items'] as List<dynamic>? ?? [];

    return UpsellResult(
      headline: headline,
      weatherCategory: weather['category'] as String? ?? 'mild',
      items: rawItems
          .map((e) => UpsellItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
