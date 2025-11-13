import 'package:flutter/material.dart';
import '../themes/app_theme.dart';
import 'feedback_screen.dart';

class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Track Order'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: color.primary,
        foregroundColor: color.onPrimary,
        onPressed: () {},
        child: const Icon(Icons.mic_none_rounded),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ////// Order Info Card //////
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order #A12345',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                    const SizedBox(height: 8),
                    Text('Estimated Delivery',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.hintColor)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            color: color.primary, size: 18),
                        const SizedBox(width: 6),
                        Text('30–40 mins',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: color.primary,
                            )),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: 0.4,
                      backgroundColor: color.primary.withOpacity(0.2),
                      color: color.primary,
                      minHeight: 4,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            ////// Status Steps //////
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  children: [
                    _buildStatusRow(context,
                        icon: Icons.check_circle,
                        title: 'Order Confirmed',
                        done: true),
                    _buildStatusRow(context,
                        icon: Icons.restaurant_menu,
                        title: 'Preparing',
                        inProgress: true),
                    _buildStatusRow(context,
                        icon: Icons.delivery_dining,
                        title: 'Out for Delivery'),
                    _buildStatusRow(context,
                        icon: Icons.home_filled,
                        title: 'Delivered'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            ////// Order Items Card //////
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order Items',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.hintColor)),
                        Text('\$2.99',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.call, size: 18),
                          label: const Text('Call Restaurant'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: color.primary),
                            foregroundColor: color.primary,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.chat, size: 18),
                          label: const Text('Chat Support'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: color.primary),
                            foregroundColor: color.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            ////// View Order History Button //////
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/order_history');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: color.primary,
                  foregroundColor: color.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('View Order History'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context,
      {required IconData icon,
        required String title,
        bool done = false,
        bool inProgress = false}) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    return ListTile(
      leading: Icon(icon,
          color: done
              ? Colors.green
              : inProgress
              ? color.primary
              : theme.hintColor),
      title: Text(title,
          style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: done
                  ? Colors.green
                  : inProgress
                  ? color.primary
                  : theme.hintColor)),
      trailing: done
          ? const Icon(Icons.check, color: Colors.green)
          : inProgress
          ? Text('In Progress',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: color.primary))
          : null,
    );
  }
}
