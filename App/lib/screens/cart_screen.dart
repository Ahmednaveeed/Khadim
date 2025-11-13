import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  final List<CartItem> items;
  const CartScreen({Key? key, required this.items}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late List<CartItem> cartItems;

  @override
  void initState() {
    super.initState();
    // Copy list so it can be modified
    cartItems = widget.items.map((e) => e.copyWith()).toList();
  }

  double get subtotal => cartItems.fold(
    0.0,
        (sum, item) =>
    sum + (double.parse(item.price.replaceAll(RegExp(r'[^0-9.]'), '')) * item.quantity),
  );

  double get tax => subtotal * 0.08; // 8% example
  double get deliveryFee => 2.99;
  double get total => subtotal + tax + deliveryFee;

  void increaseQty(int index) {
    setState(() => cartItems[index].quantity++);
  }

  void decreaseQty(int index) {
    setState(() {
      if (cartItems[index].quantity > 1) {
        cartItems[index].quantity--;
      } else {
        cartItems.removeAt(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Your Cart"),
          actions: [
            if (cartItems.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  setState(() => cartItems.clear());
                },
              ),
          ],
        ),
        body: cartItems.isEmpty
            ? const Center(
          child: Text(
            "Your cart is empty",
            style: TextStyle(fontSize: 16),
          ),
        )
            : Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: cartItems.length,
                itemBuilder: (context, index) {
                  final item = cartItems[index];
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          item.image,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(item.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(item.price),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            color: Colors.orangeAccent,
                            onPressed: () => decreaseQty(index),
                          ),
                          Text(
                            item.quantity.toString(),
                            style: const TextStyle(fontSize: 16),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            color: Colors.orangeAccent,
                            onPressed: () => increaseQty(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            ////// Summary Section ///////
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSummaryRow("Subtotal", "\$${subtotal.toStringAsFixed(2)}"),
                  _buildSummaryRow("Tax", "\$${tax.toStringAsFixed(2)}"),
                  _buildSummaryRow("Delivery Fee", "\$${deliveryFee.toStringAsFixed(2)}"),
                  const Divider(),
                  _buildSummaryRow(
                    "Total",
                    "\$${total.toStringAsFixed(2)}",
                    isBold: true,
                    color: Colors.black87,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CheckoutScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.white,
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Proceed to Checkout",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {bool isBold = false, Color color = Colors.grey}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
