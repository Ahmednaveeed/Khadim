import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:khaadim/services/feedback_service.dart';

class FeedbackScreen extends StatefulWidget {
  final int? orderId;
  final String feedbackType;

  /// If non-null the screen shows custom-deal feedback UI.
  final int? customDealId;

  const FeedbackScreen({
    super.key,
    this.orderId,
    this.feedbackType = "GENERAL",
    this.customDealId,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  double _rating = 0;
  bool _submitting = false;
  final TextEditingController _commentController = TextEditingController();

  // ── Custom-deal per-item rating state ────────────────────────────
  bool _showItemRatings = false;
  bool _loadingItems = false;
  List<Map<String, dynamic>> _dealItems = [];
  final Map<int, double> _itemRatings = {}; // item_id → rating

  @override
  void initState() {
    super.initState();
    if (_isCustomDeal) _fetchDealItems();
  }

  bool get _isCustomDeal => widget.customDealId != null;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // ── Fetch items from custom_deal_items (for per-item stars) ──────
  Future<void> _fetchDealItems() async {
    setState(() => _loadingItems = true);
    try {
      final res =
          await FeedbackService.getCustomDealItems(widget.customDealId!);
      final items = (res['items'] as List?) ?? [];
      _dealItems = items.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      // silently fail; per-item section just won't show
    } finally {
      if (mounted) setState(() => _loadingItems = false);
    }
  }

  // ── Submit ───────────────────────────────────────────────────────
  Future<void> _submitFeedback() async {
    final String message = _commentController.text.trim();

    if (_rating <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write your feedback')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      if (_isCustomDeal) {
        // Build item_ratings list from only items the user actually rated
        final List<Map<String, int>> ratedItems = [];
        _itemRatings.forEach((itemId, rating) {
          if (rating > 0) {
            ratedItems.add({'item_id': itemId, 'rating': rating.round()});
          }
        });

        await FeedbackService.submitCustomDealFeedback(
          orderId: widget.orderId!,
          customDealId: widget.customDealId!,
          overallRating: _rating.round(),
          message: message,
          itemRatings: ratedItems,
        );
      } else {
        await FeedbackService.submitFeedback(
          rating: _rating.round(),
          message: message,
          orderId: widget.orderId,
          feedbackType: widget.feedbackType,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback submitted successfully')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCustomDeal ? 'Rate Custom Deal' : 'Rate Your Order'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isCustomDeal
                  ? 'How was your custom deal?'
                  : 'How was your experience?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.orderId != null
                  ? 'Order #${widget.orderId}'
                  : 'Share your feedback with us',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 28),

            // ── Overall star rating ─────────────────────────────────
            Center(
              child: RatingBar.builder(
                initialRating: 0,
                minRating: 1,
                allowHalfRating: false,
                itemCount: 5,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4),
                itemBuilder: (context, _) => const Icon(
                  Icons.star,
                  color: Colors.amber,
                ),
                onRatingUpdate: (value) {
                  _rating = value;
                },
              ),
            ),
            const SizedBox(height: 28),

            // ── Per-item ratings (custom deal only) ─────────────────
            if (_isCustomDeal && !_loadingItems && _dealItems.isNotEmpty) ...[
              _buildItemRatingsSection(theme),
              const SizedBox(height: 20),
            ],
            if (_isCustomDeal && _loadingItems)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),

            // ── Comment box ─────────────────────────────────────────
            TextField(
              controller: _commentController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Write your feedback...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
              ),
            ),
            const SizedBox(height: 28),

            // ── Submit button ───────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit Feedback'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Expandable per-item rating section ────────────────────────────
  Widget _buildItemRatingsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _showItemRatings = !_showItemRatings),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  _showItemRatings
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Rate individual items (optional)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showItemRatings)
          Card(
            margin: const EdgeInsets.only(top: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: _dealItems.map((item) {
                  final int itemId = (item['item_id'] as num).toInt();
                  final String name = item['item_name']?.toString() ?? 'Item';
                  final int qty = (item['quantity'] as num?)?.toInt() ?? 1;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$qty× $name',
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        RatingBar.builder(
                          initialRating: _itemRatings[itemId] ?? 0,
                          minRating: 0,
                          allowHalfRating: false,
                          itemCount: 5,
                          itemSize: 22,
                          unratedColor: Colors.grey.shade300,
                          itemBuilder: (context, _) => const Icon(
                            Icons.star,
                            color: Colors.amber,
                          ),
                          onRatingUpdate: (value) {
                            setState(() => _itemRatings[itemId] = value);
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}