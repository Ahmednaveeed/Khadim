class OfferModel {
  final int offerId;
  final String title;
  final String description;
  final String offerCode;
  final DateTime? validity;
  final String category;

  const OfferModel({
    required this.offerId,
    required this.title,
    required this.description,
    required this.offerCode,
    required this.validity,
    required this.category,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    return OfferModel(
      offerId: (json['offer_id'] ?? 0) as int,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      offerCode: json['offer_code']?.toString() ?? '',
      validity: json['validity'] != null
          ? DateTime.tryParse(json['validity'])
          : null,
      category: json['category']?.toString() ?? '',
    );
  }
}