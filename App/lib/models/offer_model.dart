class OfferModel {
  final int offerId;
  final String title;
  final String description;
  final String offerCode;
  final String validity; // ISO string from backend
  final String category;

  OfferModel({
    required this.offerId,
    required this.title,
    required this.description,
    required this.offerCode,
    required this.validity,
    required this.category,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    return OfferModel(
      offerId: json['offer_id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      offerCode: (json['offer_code'] ?? '') as String,
      validity: json['validity'] as String,
      category: json['category'] as String,
    );
  }
}
