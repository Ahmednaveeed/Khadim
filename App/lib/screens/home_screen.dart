import 'package:flutter/material.dart';
import 'offer_screen.dart';
import 'profile_screen.dart';
import 'menu_screen.dart';
import '../models/cart_item.dart';
import 'cart_screen.dart';


class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

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
                // Open CartScreen even if empty (no items yet)
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartScreen(items: [])),
                );
              },
            ),
          ],

        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ////// Section 1 ///////
            _buildSectionHeader(context, "Personalized for You"),
            const SizedBox(height: 8),
            _buildDealCard(
              context,
              image: "assets/images/burger.png",
              title: "Lunch Combo",
              subtitle: "Any burger + fries + drink",
              oldPrice: "\$22.99",
              newPrice: "\$15.99",
              discount: "30%",
            ),
            const SizedBox(height: 12),
            _buildDealCard(
              context,
              image: "assets/images/pizza.png",
              title: "Pizza Night",
              subtitle: "Large pizza + 2 drinks",
              oldPrice: "\$27.99",
              newPrice: "\$19.99",
              discount: "29%",
            ),
            const SizedBox(height: 24),

            ////// Section 2 ///////
            _buildSectionHeader(context, "You Might Also Like"),
            const SizedBox(height: 8),
            _buildDealCard(
              context,
              image: "assets/images/pasta.png",
              title: "Family Feast",
              subtitle: "2 pizzas + pasta + salad + dessert",
              oldPrice: "\$65.99",
              newPrice: "\$49.99",
              discount: "25%",
            ),
            const SizedBox(height: 12),
            _buildDealCard(
              context,
              image: "assets/images/cake.png",
              title: "Sweet Treat",
              subtitle: "Any dessert + coffee",
              oldPrice: "\$14.99",
              newPrice: "\$9.99",
              discount: "33%",
            ),
          ],
        ),
      ),
    );
  }

  ////// Section Header Widget ///////
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

  ////// Deal Card Widget ///////
  Widget _buildDealCard(BuildContext context, {
    required String image,
    required String title,
    required String subtitle,
    required String oldPrice,
    required String newPrice,
    required String discount,
  }) {
    final theme = Theme.of(context);

    return Container(
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            child: Image.asset(
              image,
              width: 110,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ////// Title + Discount Badge ///////
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          discount,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  ////// Subtitle ///////
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  ////// Prices + Add Button ///////
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            oldPrice,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            newPrice,
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () {
                          final item = CartItem(
                            title: title,
                            price: newPrice,
                            image: image,
                          );

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CartScreen(items: [item]),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text("Add"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
