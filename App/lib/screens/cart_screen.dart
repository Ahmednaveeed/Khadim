import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late List<CartItem> cartItems;

  @override
  void initState() {
    super.initState();

    // Load current provider items into a local editable list
    cartItems = context.read<CartProvider>().items
        .map((e) => e.copyWith())
        .toList();
  }

  double get subtotal =>
      cartItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

  double get tax => subtotal * 0.08;
  double get deliveryFee => 2.99;
  double get total => subtotal + tax + deliveryFee;

  void increaseQty(int index) {
    final provider = context.read<CartProvider>();
    provider.increaseQuantity(cartItems[index]);

    setState(() {
      cartItems[index].quantity++;
    });
  }

  void decreaseQty(int index) {
    final provider = context.read<CartProvider>();

    if (cartItems[index].quantity > 1) {
      provider.decreaseQuantity(cartItems[index]);
      setState(() {
        cartItems[index].quantity--;
      });
    } else {
      provider.removeItem(cartItems[index]);
      setState(() {
        cartItems.removeAt(index);
      });
    }
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
                  context.read<CartProvider>().clear();
                  setState(() => cartItems.clear());
                },
              ),
          ],
        ),

        body: cartItems.isEmpty
            ? const Center(
          child: Text("Your cart is empty",
              style: TextStyle(fontSize: 16)),
        )
            : Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: cartItems.length,
                itemBuilder: (_, index) {
                  final item = cartItems[index];

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item.image != null
                            ? Image.asset(
                          item.image!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        )
                            : Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.fastfood),
                        ),
                      ),

                      title: Text(
                        item.title ?? item.name ?? "Item",
                        style: const TextStyle(
                            fontWeight: FontWeight.w600),
                      ),

                      subtitle: Text(
                        "Rs ${item.price}",
                        style: const TextStyle(color: Colors.grey),
                      ),

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

            // Summary Section
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                      "Subtotal", "Rs ${subtotal.toStringAsFixed(2)}"),
                  _buildSummaryRow(
                      "Tax", "Rs ${tax.toStringAsFixed(2)}"),
                  _buildSummaryRow("Delivery Fee",
                      "Rs ${deliveryFee.toStringAsFixed(2)}"),
                  const Divider(),
                  _buildSummaryRow(
                    "Total",
                    "Rs ${total.toStringAsFixed(2)}",
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

  Widget _buildSummaryRow(
      String label,
      String value, {
        bool isBold = false,
        Color color = Colors.grey,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight:
                  isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight:
                  isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
