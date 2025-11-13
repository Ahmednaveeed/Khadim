import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import 'cart_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final categories = [
      "All", "Burgers", "Pizza", "Pasta", "Salads", "Desserts", "Drinks"
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Menu"),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () {
              // Open empty cart if no items added yet
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen(items: [])),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ////// Search Bar ///////
            TextField(
              decoration: InputDecoration(
                hintText: "Search menu...",
                prefixIcon: const Icon(Icons.search),
                fillColor: theme.colorScheme.surface,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            ////// Category Filter ///////
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final isSelected = index == 0;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      backgroundColor: Colors.transparent,
                      selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                      label: Text(
                        categories[index],
                        style: TextStyle(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                      onSelected: (_) {},
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            ////// Menu Items ///////
            _buildMenuCard(
              context,
              image: "assets/images/burger.png",
              title: "Classic Burger",
              subtitle: "Juicy beef patty with lettuce, tomato, and special sauce",
              price: "\$12.99",
              tag: "Burgers",
            ),
            const SizedBox(height: 12),

            _buildMenuCard(
              context,
              image: "assets/images/pizza.png",
              title: "Margherita Pizza",
              subtitle: "Fresh mozzarella, tomato sauce, and basil",
              price: "\$14.99",
              tag: "Pizza",
            ),
            const SizedBox(height: 12),

            _buildMenuCard(
              context,
              image: "assets/images/pasta.png",
              title: "Creamy Pasta",
              subtitle: "Fettuccine with creamy Alfredo sauce and parmesan",
              price: "\$16.99",
              tag: "Pasta",
            ),
            const SizedBox(height: 12),

            _buildMenuCard(
              context,
              image: "assets/images/cake.png",
              title: "Caesar Salad",
              subtitle: "Crisp romaine lettuce with Caesar dressing",
              price: "\$9.99",
              tag: "Salads",
            ),
          ],
        ),
      ),
    );
  }

  ////// Menu Card ///////
  Widget _buildMenuCard(
      BuildContext context, {
        required String image,
        required String title,
        required String subtitle,
        required String price,
        required String tag,
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                          color: Colors.deepPurple.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: Colors.deepPurple,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        price,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          final item = CartItem(
                            title: title,
                            price: price,
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
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text("Add to Cart"),
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
