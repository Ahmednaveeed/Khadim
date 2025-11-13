import 'package:flutter/material.dart';

class OffersScreen extends StatelessWidget {
  const OffersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Exclusive Offers",
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildOfferCard(
              context,
              title: "Weekend Special Combo",
              description: "Buy 1 large pizza, get 1 small free!",
              image: "assets/images/pizza.png",
              validity: "Valid till 12th Nov",
              code: "WEEKEND50",
            ),
            const SizedBox(height: 16),
            _buildOfferCard(
              context,
              title: "Burger Bonanza",
              description: "Flat 25% off on all burger meals.",
              image: "assets/images/burger.png",
              validity: "Valid till 15th Nov",
              code: "BURGER25",
            ),
            const SizedBox(height: 16),
            _buildOfferCard(
              context,
              title: "Family Feast Offer",
              description: "Get free dessert on orders above \$50.",
              image: "assets/images/cake.png",
              validity: "Valid till 20th Nov",
              code: "FAMILYFEAST",
            ),
          ],
        ),
      ),
    );
  }

  /// Offer Card Widget
  Widget _buildOfferCard(
      BuildContext context, {
        required String title,
        required String description,
        required String image,
        required String validity,
        required String code,
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
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "🎟️ Use Code: $code",
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    validity,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
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
