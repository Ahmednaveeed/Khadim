import 'package:flutter/material.dart';
import 'add_payment_screen.dart';
import 'package:khaadim/services/payment_service.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({Key? key}) : super(key: key);

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final paymentService = PaymentService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = paymentService.cards;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text("Payment Methods")),
        floatingActionButton: FloatingActionButton(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.black,
          onPressed: () {},
          child: const Icon(Icons.mic_none_rounded),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddPaymentScreen(),
                    ),
                  );
                  if (result != null && result is Map<String, String>) {
                    setState(() {
                      paymentService.addCard(result);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            "Added ${result['type']} •••• ${result['last4']}"),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text("Add New Card"),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: cards.isEmpty
                    ? const Center(
                  child: Text("No cards added yet",
                      style: TextStyle(color: Colors.grey)),
                )
                    : ListView.builder(
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.credit_card,
                                  color: Colors.orange),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${card['type']} •••• ${card['last4']}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  Text("Expires ${card['expiry']}",
                                      style: const TextStyle(
                                          color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () {
                              setState(() {
                                paymentService.removeCard(index);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
