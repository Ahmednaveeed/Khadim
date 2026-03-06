import 'orderitem.dart';

class Order {
  final String orderNumber;
  final double totalAmount;
  final String address;
  final List<OrderItem> items;
  final DateTime createdAt;

  const Order({
    required this.orderNumber,
    required this.totalAmount,
    required this.address,
    required this.items,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      orderNumber: json['orderNumber']?.toString() ?? '',
      totalAmount: (json['totalAmount'] is num)
          ? (json['totalAmount'] as num).toDouble()
          : 0.0,
      address: json['address']?.toString() ?? '',
      items: (json['items'] as List? ?? [])
          .map((e) => OrderItem.fromJson(e))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ??
          DateTime.now(),
    );
  }
}