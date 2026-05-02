class AppNotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String targetRoute;
  final int? itemId;
  final String? itemName;

  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    required this.targetRoute,
    this.itemId,
    this.itemName,
  });

  AppNotificationItem copyWith({
    bool? isRead,
  }) {
    return AppNotificationItem(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      targetRoute: targetRoute,
      itemId: itemId,
      itemName: itemName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      'target_route': targetRoute,
      'item_id': itemId,
      'item_name': itemName,
    };
  }

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    return AppNotificationItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
      isRead: json['is_read'] == true,
      targetRoute: (json['target_route'] ?? '/main').toString(),
      itemId: (json['item_id'] as num?)?.toInt(),
      itemName: json['item_name']?.toString(),
    );
  }
}
