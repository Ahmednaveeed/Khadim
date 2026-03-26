import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:khaadim/providers/cart_provider.dart';
import 'package:khaadim/screens/cart/cart_screen.dart';
import 'package:khaadim/screens/discover/upsell_popup.dart';
import 'package:khaadim/screens/discover/custom_deal_screen.dart';
import 'package:khaadim/screens/home/widgets/recommended_section.dart';
import 'package:khaadim/screens/home/widgets/deals_you_love_section.dart';
import 'package:khaadim/services/personalization_service.dart';
import 'package:khaadim/models/recommendation_result.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static bool _upsellShown = false;

  late Future<RecommendationResult> _recommendationFuture;

  @override
  void initState() {
    super.initState();
    _recommendationFuture = PersonalizationService.getRecommendations(topK: 10);
    // Show upsell popup only once per app session
    if (!_upsellShown) {
      _upsellShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showUpsellPopup());
    }
  }

  void _showUpsellPopup() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => const UpsellPopup(),
    );
  }

  Future<void> _handleRefresh() async {
    // Fetch in the background first — don't call setState until data arrives.
    // Calling setState early causes a full widget rebuild which resets scroll position.
    final next = PersonalizationService.getRecommendations(topK: 10);
    try {
      await next;
    } catch (_) {
      // Ignore fetch errors; indicator will still dismiss
    }
    if (mounted) {
      setState(() { _recommendationFuture = next; });
    }
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

        body: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: theme.colorScheme.primary,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Custom Deal Card at the top
              _buildCustomDealCard(context),
              const SizedBox(height: 20),

              // ── Phase 4: AI-Personalized sections ──
              FutureBuilder<RecommendationResult>(
                future: _recommendationFuture,
                builder: (ctx, snapshot) {
                  // Only show empty state when data is loaded and BOTH sections are empty
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SizedBox.shrink();
                  }
                  final result = snapshot.data;
                  final hasItems = result != null && result.recommendedItems.isNotEmpty;
                  final hasDeals = result != null && result.recommendedDeals.isNotEmpty;
                  if (hasItems || hasDeals) return const SizedBox.shrink();

                  // New user — no data yet
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(ctx).colorScheme.outline.withOpacity(0.15),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text('🍽️', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          'Your personalized feed is waiting!',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Order and rate a few items to unlock\nyour personalized recommendations.',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.55),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),

              RecommendedForYouSection(future: _recommendationFuture),
              const SizedBox(height: 20),

              DealsYouLoveSection(future: _recommendationFuture),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Custom Deal Card
  Widget _buildCustomDealCard(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CustomDealScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Create Custom Deal",
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tell AI what you want & get a personalized deal!",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Try Now",
                          style: TextStyle(
                            color: Color(0xFFFF5722),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          color: Color(0xFFFF5722),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.restaurant_menu,
              color: Colors.white,
              size: 50,
            ),
          ],
        ),
      ),
    );
  }
}