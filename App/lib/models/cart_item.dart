class CartItem {
  final String id;
  final String? name;
  final String? title;
  double price;
  int quantity;
  final String? type;
  final String? image;

  CartItem({
    required this.id,
    this.name,
    this.title,
    required this.price,
    this.quantity = 1,
    this.type,
    this.image,
  });

  CartItem copyWith({
    String? id,
    String? name,
    String? title,
    double? price,
    int? quantity,
    String? type,
    String? image,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? this.title,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      type: type ?? this.type,
      image: image ?? this.image,
    );
  }
}
