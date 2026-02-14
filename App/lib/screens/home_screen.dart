import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/deal_model.dart';
import '../providers/cart_provider.dart';
import '../services/deal_service.dart';
import '../utils/ImageResolver.dart';
import 'cart_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<DealModel> deals = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadDeals();
  }

  Future<void> loadDeals() async {
    try {
      deals = await DealService.fetchDeals();
    } catch (e) {
      print("Error loading deals: $e");
    }
    setState(() => loading = false);
  }

  String getDealCategory(String dealName) {
    final name = dealName.toLowerCase();

    if (name.contains("fast")) return "fast_food";
    if (name.contains("bbq")) return "bbq";
    if (name.contains("chinese")) return "chinese";
    if (name.contains("desi")) return "desi";
    if (name.contains("drink")) return "drinks";

    return "fast_food";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Special deals just for you",
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                );
              },
            ),
          ],
        ),

        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 20),

            _buildSectionHeader(context, "Recommended Deals"),
            const SizedBox(height: 12),

            ...deals.map((deal) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildDealCard(
                  context,
                  deal: deal, // PASS THE WHOLE DEAL OBJECT
                  image: ImageResolver.getDealImage(
                    getDealCategory(deal.dealName),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.headlineMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDealCard(
      BuildContext context, {
        required DealModel deal,
        required String image,
      }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// IMAGE
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Image.asset(
              image,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// TITLE + SERVING SIZE
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        deal.dealName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${deal.servingSize} Person",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                /// ITEMS IN DEAL
                Text(
                  deal.items,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 10),

                /// PRICE + ADD BUTTON
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Rs ${deal.dealPrice}",
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Consumer<CartProvider>(
                      builder: (context, cart, child) {
                        return ElevatedButton(
                          onPressed: () {
                            cart.addDeal(deal); // ADD TO CART

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("${deal.dealName} added to cart"),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                          ),
                          child: const Text("Add"),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
