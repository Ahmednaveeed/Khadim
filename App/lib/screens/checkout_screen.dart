import 'package:flutter/material.dart';
import '../services/payment_service.dart';
import 'add_payment_screen.dart';
import 'order_confirmation_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({Key? key}) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _address =
  TextEditingController(text: "123 Main St, City, State 12345");

  final paymentService = PaymentService();
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final cards = paymentService.cards;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Checkout"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: color.primary,
        foregroundColor: color.onPrimary,
        onPressed: () {},
        child: const Icon(Icons.mic_none_rounded),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /////// Delivery Address ///////
            _buildSectionCard(
              context,
              title: "Delivery Address",
              child: TextField(
                controller: _address,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  labelText: "Address",
                  labelStyle: theme.textTheme.bodySmall,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                ),
              ),
            ),
            const SizedBox(height: 16),

            /////// Payment Method ///////
            _buildSectionCard(
              context,
              title: "Payment Method",
              child: Column(
                children: [
                  for (int i = 0; i < cards.length; i++)
                    _buildPaymentTile(
                      context,
                      "${cards[i]['type']} •••• ${cards[i]['last4']}",
                      "Expires ${cards[i]['expiry']}",
                      selected: _selectedIndex == i,
                      onTap: () => setState(() => _selectedIndex = i),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
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
                          _selectedIndex = cards.length - 1;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Added ${result['type']} •••• ${result['last4']}",
                            ),
                          ),
                        );
                      }
                    },
                    icon: Icon(Icons.add, color: color.primary),
                    label: Text(
                      "Add New Payment Method",
                      style: TextStyle(color: color.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: color.primary),
                      foregroundColor: color.primary,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            /////// Order Summary ///////
            _buildSectionCard(
              context,
              title: "Order Summary",
              child: Column(
                children: [
                  const _SummaryRow("Subtotal", "\$0.00"),
                  const _SummaryRow("Tax", "\$0.00"),
                  const _SummaryRow("Delivery Fee", "\$2.99"),
                  const Divider(),
                  _SummaryRow(
                    "Total",
                    "\$2.99",
                    isBold: true,
                    color: theme.colorScheme.onBackground,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            /////// Confirm Button ///////
            ElevatedButton(
              onPressed: () {
                final selected = cards[_selectedIndex];
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Paid with ${selected['type']} •••• ${selected['last4']} — processing your order...",
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );

                Future.delayed(const Duration(seconds: 1), () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OrderConfirmationScreen(
                        orderNumber: "A12345",
                        totalAmount: 2.99,
                      ),
                    ),
                  );
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color.primary,
                foregroundColor: color.onPrimary,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text("Place Order"),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Helper Widgets ----------

  static Widget _buildSectionCard(BuildContext context,
      {required String title, required Widget child}) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardColor,
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  static Widget _buildPaymentTile(
      BuildContext context,
      String title,
      String subtitle, {
        required bool selected,
        required VoidCallback onTap,
      }) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(
          color: selected
              ? color.primary
              : color.primary.withOpacity(0.4),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading:
        Icon(Icons.credit_card_outlined, color: color.primary),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.hintColor,
          ),
        ),
        trailing: selected
            ? Icon(Icons.check_circle, color: color.primary)
            : null,
        onTap: onTap,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  final bool isBold;
  final Color color;
  const _SummaryRow(
      this.label,
      this.value, {
        this.isBold = false,
        this.color = Colors.grey,
        Key? key,
      }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight:
              isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight:
              isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
