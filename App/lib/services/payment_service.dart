class PaymentService {
  // Singleton pattern
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  // List of saved cards
  final List<Map<String, String>> cards = [
    {"type": "Visa", "last4": "4242", "expiry": "12/25"},
    {"type": "Mastercard", "last4": "5555", "expiry": "08/26"},
  ];

  void addCard(Map<String, String> card) => cards.add(card);
  void removeCard(int index) => cards.removeAt(index);
}
