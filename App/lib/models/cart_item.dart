
class CartItem {
  final String title;
  final String price;
  final String image;
  int quantity;

  CartItem({
    required this.title,
    required this.price,
    required this.image,
    this.quantity = 1,
  });

  /// Creates a copy of the current item
  CartItem copyWith({
    String? title,
    String? price,
    String? image,
    int? quantity,
  }) {
    return CartItem(
      title: title ?? this.title,
      price: price ?? this.price,
      image: image ?? this.image,
      quantity: quantity ?? this.quantity,
    );
  }
}
