class DealModel {
  final int dealId;
  final String dealName;
  final double dealPrice;
  final int servingSize;
  final String items;
  final String imageUrl;

  DealModel({
    required this.dealId,
    required this.dealName,
    required this.dealPrice,
    required this.servingSize,
    required this.items,
    required this.imageUrl,
  });

  factory DealModel.fromJson(Map<String, dynamic> json) {
    return DealModel(
      dealId: json['deal_id'],
      dealName: json['deal_name'],
      dealPrice: (json['deal_price'] as num).toDouble(),
      servingSize: json['serving_size'],
      items: json['items'],
      imageUrl: json['image_url'] ?? '',
    );
  }
}
