// Phase 4 - Personalization Flutter UI
import 'package:flutter/material.dart';

import 'package:khaadim/models/recommendation_result.dart';
import 'package:khaadim/services/cart_service.dart';
import 'package:khaadim/providers/cart_provider.dart';
import 'package:khaadim/utils/ImageResolver.dart';
import 'package:provider/provider.dart';

class DealsYouLoveSection extends StatefulWidget {
  final Future<RecommendationResult> future;
  final int? highlightDealId;
  final String? highlightDealName;

  const DealsYouLoveSection({
    super.key,
    required this.future,
    this.highlightDealId,
    this.highlightDealName,
  });

  @override
  State<DealsYouLoveSection> createState() => _DealsYouLoveSectionState();
}

class _DealsYouLoveSectionState extends State<DealsYouLoveSection>
    with TickerProviderStateMixin {
  final Set<int> _adding = {};

  // Shimmer while loading
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnim;

  // Pulsing glow on the highlighted card
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // Keys for scrolling
  final Map<int, GlobalKey> _dealKeys = {};
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

  void _maybeScrollToHighlight(int dealId) {
    if (_hasScrolledToHighlight) return;
    if (widget.highlightDealId == null) return;
    if (dealId != widget.highlightDealId) return;

    _hasScrolledToHighlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _dealKeys[dealId];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
          alignment: 0.25,
        );
      }
    });
  }

  Future<void> _addDeal(RecommendedDeal deal) async {
    final cartId = context.read<CartProvider>().cartId;
    final cartProvider = context.read<CartProvider>();
    if (cartId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart not ready, please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _adding.add(deal.dealId));
    try {
      await CartService.addItem(
        cartId: cartId,
        itemType: 'deal',
        itemId: deal.dealId,
        quantity: 1,
      );
      await cartProvider.sync();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${deal.dealName} added!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not add ${deal.dealName}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _adding.remove(deal.dealId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RecommendationResult>(
      future: widget.future,
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerSection(context);
        }
        final result = snapshot.data;
        if (result == null || result.recommendedDeals.isEmpty) {
          return const SizedBox.shrink();
        }

        final displayDeals = List<RecommendedDeal>.from(result.recommendedDeals);

        // Inject highlighted deal if missing
        if (widget.highlightDealId != null &&
            widget.highlightDealName != null &&
            !displayDeals.any((d) => d.dealId == widget.highlightDealId)) {
          displayDeals.insert(
            0,
            RecommendedDeal(
              dealId: widget.highlightDealId!,
              dealName: widget.highlightDealName!,
              score: 0.0,
              reason: 'A deal you love',
              source: 'favourite_deal',
              category: 'deal',
              items: '', // We don't have items without another fetch
            ),
          );
        }

        return _buildSection(context, displayDeals);
      },
    );
  }

  Widget _buildSection(BuildContext context, List<RecommendedDeal> deals) {
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
                "Deals You'll Love",
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
          itemCount: deals.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) => _buildDealCard(ctx, deals[i]),
        ),
      ],
    );
  }

  Widget _buildDealCard(BuildContext context, RecommendedDeal deal) {
    final theme = Theme.of(context);
    final isAdding = _adding.contains(deal.dealId);

    // Track scroll target
    if (!_dealKeys.containsKey(deal.dealId)) {
      _dealKeys[deal.dealId] = GlobalKey();
    }
    _maybeScrollToHighlight(deal.dealId);

    final isHighlighted = widget.highlightDealId == deal.dealId;

    Widget card = Container(
      key: _dealKeys[deal.dealId],
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
      child: Row(
        children: [
          // Deal image — left side
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14),
            ),
            child: Image.asset(
              ImageResolver.getDealImage(deal.dealName),
              width: 90,
              height: 90,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 90,
                height: 90,
                color: Colors.grey.shade100,
                child: const Icon(Icons.local_offer_outlined,
                    color: Colors.grey, size: 32),
              ),
            ),
          ),
          // Content — right side
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          deal.dealName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isHighlighted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '✦ Just For You',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (deal.reason.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      deal.reason,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // View items link
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text(deal.dealName),
                              content: Text(deal.items.isNotEmpty
                                  ? deal.items
                                  : 'Includes multiple items from our menu.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View items',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.arrow_forward_ios_rounded,
                                color: theme.colorScheme.primary, size: 10),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Add button
                      SizedBox(
                        height: 28,
                        child: ElevatedButton(
                          onPressed: isAdding ? null : () => _addDeal(deal),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (isHighlighted) {
      return AnimatedBuilder(
        animation: _pulseAnim,
        builder: (ctx, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(
                    0.05 + (_pulseAnim.value * 0.15),
                  ),
                  blurRadius: 10 + (_pulseAnim.value * 10),
                  spreadRadius: _pulseAnim.value * 2,
                ),
              ],
            ),
            child: child,
          );
        },
        child: card,
      );
    }

    return card;
  }

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
              width: 160,
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
