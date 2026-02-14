class MenuItemModel {
  final int itemId;
  final String itemName;
  final String itemDescription;
  final String itemCategory;
  final String itemCuisine;
  final double itemPrice;
  final String quantityDescription;
  final String imageUrl;

  MenuItemModel({
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
      itemId: json['item_id'],
      itemName: json['item_name'],
      itemDescription: json['item_description'] ?? '',
      itemCategory: json['item_category'],
      itemCuisine: json['item_cuisine'],
      itemPrice: (json['item_price'] as num).toDouble(),
      quantityDescription: json['quantity_description'] ?? '',
      imageUrl: json['image_url'] ?? '',
    );
  }
}
