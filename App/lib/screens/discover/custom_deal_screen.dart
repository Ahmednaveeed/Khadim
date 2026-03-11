import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/custom_deal_model.dart';
import '../../providers/cart_provider.dart';
import '../../services/deal_service.dart';
import '../../services/cart_service.dart';

class CustomDealScreen extends StatefulWidget {
  const CustomDealScreen({super.key});

  @override
  State<CustomDealScreen> createState() => _CustomDealScreenState();
}

class _CustomDealScreenState extends State<CustomDealScreen> {
  final TextEditingController _keywordsController = TextEditingController();

  int _personCount = 1;
  bool _isLoading = false;
  CustomDealResponse? _dealResponse;
  String? _error;

  @override
  void dispose() {
    _keywordsController.dispose();
    super.dispose();
  }

  Future<void> _createDeal() async {
    final keywords = _keywordsController.text.trim();
    // Build a combined query from person count + keywords
    final query = keywords.isEmpty
        ? "Make a deal for $_personCount person${_personCount > 1 ? 's' : ''}"
        : "Make a deal for $_personCount person${_personCount > 1 ? 's' : ''} with $keywords";

    setState(() {
      _isLoading = true;
      _error = null;
      _dealResponse = null;
    });

    try {
      final response = await DealService.createCustomDeal(query);
      final deal = CustomDealResponse.fromJson(response);
      setState(() {
        _dealResponse = deal;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addToCart() async {
    if (_dealResponse == null || !_dealResponse!.hasItems) return;

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final cartId = cartProvider.cartId;

    if (cartId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cart not available")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      for (final item in _dealResponse!.items) {
        await CartService.addItem(
          cartId: cartId,
          itemType: item.itemType,
          itemId: item.itemId,
          quantity: item.quantity,
        );
      }

      await cartProvider.sync();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Custom deal added to cart!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Custom Deal"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── PERSON COUNTER ──────────────────────────────────────
            Text(
              "Person",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Minus
                _CounterButton(
                  icon: Icons.remove,
                  onTap: () {
                    if (_personCount > 1) {
                      setState(() => _personCount--);
                    }
                  },
                ),
                const SizedBox(width: 16),
                // Count display
                Container(
                  width: 80,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    "$_personCount",
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Plus
                _CounterButton(
                  icon: Icons.add,
                  onTap: () => setState(() => _personCount++),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── KEYWORDS ────────────────────────────────────────────
            Text(
              "Keywords",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keywordsController,
              decoration: InputDecoration(
                hintText: "Description / words  e.g. something Pakistani",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.4),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.4),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),

            const SizedBox(height: 28),

            // ── SUBMIT BUTTON ────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createDeal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Create Deal",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            // ── ERROR ────────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── DEAL RESULT ──────────────────────────────────────────
            if (_dealResponse != null && !_isLoading) ...[
              const SizedBox(height: 24),
              _buildDealResult(theme),
            ],
          ],
        ),
      ),
    );
  }

  /// Strips markdown bold markers (**text**) and emoji characters from a string.
  String _cleanMessage(String msg) {
    return msg
        .replaceAll(RegExp(r'\*\*'), '')
        .replaceAll(RegExp(r'[\u{1F000}-\u{1FFFF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{2600}-\u{26FF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{2700}-\u{27BF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{FE00}-\u{FEFF}]', unicode: true), '')
        .replaceAll(RegExp(r'  +'), ' ')
        .trim();
  }

  Widget _buildDealResult(ThemeData theme) {
    final deal = _dealResponse!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: deal.success ? Colors.green : Colors.orange,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row
          Row(
            children: [
              Icon(
                deal.success ? Icons.check_circle : Icons.info_outline,
                color: deal.success ? Colors.green : Colors.orange,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  deal.success ? "Deal Created!" : "Need More Info",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: deal.success ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(_cleanMessage(deal.message), style: theme.textTheme.bodyMedium),

          // Deal items table
          if (deal.hasItems) ...[
            const Divider(height: 28),
            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Deal Items",
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  "Qty",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 8),
            ...deal.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.itemName,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Container(
                    width: 32,
                    alignment: Alignment.center,
                    child: Text(
                      "${item.quantity}",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 72,
                    child: Text(
                      "Rs ${(item.price * item.quantity).toStringAsFixed(0)}",
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )),

            const Divider(height: 24),

            // Price row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Price",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Rs ${deal.totalPrice.toStringAsFixed(0)}",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Add to cart
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _addToCart,
                icon: const Icon(Icons.shopping_cart),
                label: const Text("Add to Cart"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],

          if (!deal.success && !deal.hasItems) ...[
            const SizedBox(height: 12),
            Text(
              "Try adding more detail in keywords, e.g.:\n"
              "• Pakistani  • Biryani  • Fast food  • BBQ",
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A round +/- button used in the person counter.
class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CounterButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}
