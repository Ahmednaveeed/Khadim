// lib/screens/home/widgets/recommended_section.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:khaadim/models/recommendation_result.dart';
import 'package:khaadim/providers/cart_provider.dart';
import 'package:khaadim/services/cart_service.dart';
import 'package:khaadim/utils/ImageResolver.dart';

class RecommendedForYouSection extends StatefulWidget {
  final Future<RecommendationResult> future;

  /// When set, this item card will be highlighted and scrolled into view.
  /// Used when the user arrives via a re-engagement notification.
  final int? highlightItemId;
  final String? highlightItemName;

  const RecommendedForYouSection({
    super.key,
    required this.future,
    this.highlightItemId,
    this.highlightItemName,
  });

  @override
  State<RecommendedForYouSection> createState() =>
      _RecommendedForYouSectionState();
}

class _RecommendedForYouSectionState extends State<RecommendedForYouSection>
    with TickerProviderStateMixin {
  final Set<int> _adding = {};

  // Shimmer while loading
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnim;

  // Pulsing glow on the highlighted card
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // One GlobalKey per item so we can Scrollable.ensureVisible
  final Map<int, GlobalKey> _itemKeys = {};
  bool _hasScrolledToHighlight = false;

  @override
  void initState() {
    super.initState();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _shimmerAnim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ─── cart ──────────────────────────────────────────────────────────────────

  Future<void> _addToCart(BuildContext ctx, RecommendedItem item) async {
    final cart = Provider.of<CartProvider>(ctx, listen: false);
    if (cart.cartId == null) return;
    setState(() => _adding.add(item.itemId));
    try {
      await CartService.addItem(
        cartId: cart.cartId!,
        itemType: 'menu_item',
        itemId: item.itemId,
        quantity: 1,
      );
      await cart.sync();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${item.itemName} added to cart!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not add ${item.itemName}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ));
    } finally {
      if (mounted) setState(() => _adding.remove(item.itemId));
    }
  }

  // ─── scroll to highlighted card ────────────────────────────────────────────

  void _maybeScrollToHighlight(int itemId) {
    if (_hasScrolledToHighlight) return;
    if (widget.highlightItemId == null) return;
    if (itemId != widget.highlightItemId) return;

    _hasScrolledToHighlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _itemKeys[itemId];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
          alignment: 0.25, // item sits roughly 1/4 from the top
        );
      }
    });
  }

  // ─── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RecommendationResult>(
      future: widget.future,
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerSection(context);
        }
        final result = snapshot.data;
        if (result == null || result.recommendedItems.isEmpty) {
          return const SizedBox.shrink();
        }
        // Exclude bread items from the personalized feed
        final filtered = result.recommendedItems
            .where((item) => item.category.toLowerCase() != 'bread')
            .toList();

        // If we arrived via a notification highlighting a specific item (like a favourite)
        // and it's not in the personalized list, force it to the top so the user can see it.
        if (widget.highlightItemId != null &&
            widget.highlightItemName != null &&
            !filtered.any((i) => i.itemId == widget.highlightItemId)) {
          filtered.insert(
            0,
            RecommendedItem(
              itemId: widget.highlightItemId!,
              itemName: widget.highlightItemName!,
              score: 0.0,
              reason: 'One of your favourites',
              source: 'favourite',
              category: 'fast_food', // safe fallback for image resolution
            ),
          );
        }

        if (filtered.isEmpty) return const SizedBox.shrink();
        return _buildSection(context, filtered);
      },
    );
  }

  Widget _buildSection(BuildContext context, List<RecommendedItem> items) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Personalized For You',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          clipBehavior: Clip.none,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) => _buildItemCard(ctx, items[i]),
        ),
      ],
    );
  }

  Widget _buildItemCard(BuildContext context, RecommendedItem item) {
    final theme = Theme.of(context);
    final isAdding = _adding.contains(item.itemId);
    final isHighlighted =
        widget.highlightItemId != null && item.itemId == widget.highlightItemId;

    // Assign a stable key so we can scroll to it
    _itemKeys[item.itemId] ??= GlobalKey();

    // Schedule the scroll once after the list is painted
    if (isHighlighted) _maybeScrollToHighlight(item.itemId);

    Widget card = Container(
      key: _itemKeys[item.itemId],
      decoration: BoxDecoration(
        color: isHighlighted
            ? theme.colorScheme.primary.withOpacity(0.06)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: isHighlighted
                ? theme.colorScheme.primary.withOpacity(0.18)
                : Colors.black.withOpacity(0.05),
            blurRadius: isHighlighted ? 14 : 8,
            spreadRadius: isHighlighted ? 1 : 0,
            offset: const Offset(0, 2),
          ),
        ],
        border: isHighlighted
            ? Border.all(color: theme.colorScheme.primary, width: 2)
            : Border.all(color: theme.colorScheme.outline.withOpacity(0.10)),
      ),
      child: Stack(
        children: [
          Row(
            children: [
              // Item image
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
                child: Image.asset(
                  ImageResolver.getMenuImage(item.category, item.itemName),
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 90,
                    height: 90,
                    color: Colors.grey.shade100,
                    child: const Icon(Icons.fastfood,
                        color: Colors.grey, size: 32),
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.itemName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.reason.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.reason,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.5),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          height: 28,
                          child: ElevatedButton(
                            onPressed: isAdding
                                ? null
                                : () => _addToCart(context, item),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: isAdding
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    '+ Add',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── "Just For You" badge on highlighted card ──────────────────────
          if (isHighlighted)
            Positioned(
              top: 8,
              right: 8,
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Opacity(
                  opacity: _pulseAnim.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '✦ Just For You',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return card;
  }

  // ─── shimmer placeholder ────────────────────────────────────────────────────

  Widget _buildShimmerSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AnimatedBuilder(
            animation: _shimmerAnim,
            builder: (_, __) => Container(
              height: 18,
              width: 180,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface
                    .withOpacity(_shimmerAnim.value * 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, __) => AnimatedBuilder(
            animation: _shimmerAnim,
            builder: (_, __) => Container(
              height: 90,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface
                    .withOpacity(_shimmerAnim.value * 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
