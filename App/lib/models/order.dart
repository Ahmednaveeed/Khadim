class Order {
  final String orderNumber;
  final double totalAmount;
  final String address;
  final List<Map<String, dynamic>> items;
  final DateTime createdAt;

  Order({
    required this.orderNumber,
    required this.totalAmount,
    required this.address,
    required this.items,
    required this.createdAt,
  });

  // Ready for backend integration
  Map<String, dynamic> toJson() => {
    'orderNumber': orderNumber,
    'totalAmount': totalAmount,
    'address': address,
    'items': items,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      orderNumber: json['orderNumber'],
      totalAmount: json['totalAmount'],
      address: json['address'],
      items: List<Map<String, dynamic>>.from(json['items']),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
