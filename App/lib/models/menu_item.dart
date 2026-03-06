class MenuItemModel {
  final int itemId;
  final String itemName;
  final String itemDescription;
  final String itemCategory;
  final String itemCuisine;
  final double itemPrice;
  final String quantityDescription;
  final String imageUrl;

  const MenuItemModel({
    required this.itemId,
    required this.itemName,
    required this.itemDescription,
    required this.itemCategory,
    required this.itemCuisine,
    required this.itemPrice,
    required this.quantityDescription,
    required this.imageUrl,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    return MenuItemModel(
      itemId: (json['item_id'] ?? 0) as int,
      itemName: json['item_name']?.toString() ?? '',
      itemDescription: json['item_description']?.toString() ?? '',
      itemCategory: json['item_category']?.toString() ?? '',
      itemCuisine: json['item_cuisine']?.toString() ?? '',
      itemPrice: (json['item_price'] is num)
          ? (json['item_price'] as num).toDouble()
          : 0.0,
      quantityDescription: json['quantity_description']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
    );
  }
}