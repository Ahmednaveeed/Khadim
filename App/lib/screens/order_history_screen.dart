import 'package:flutter/material.dart';
import 'feedback_screen.dart';

class OrderHistoryScreen extends StatelessWidget {
  final Map<String, dynamic>? latestOrder;

  const OrderHistoryScreen({super.key, this.latestOrder});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    ////// Dummy Data + Latest Order //////
    final orders = [
      {
        'number': 'A1001',
        'amount': 18.50,
        'time': '2024-11-10 15:20',
        'status': 'Delivered',
      },
      {
        'number': 'A1002',
        'amount': 22.99,
        'time': '2024-11-11 13:45',
        'status': 'Delivered',
      },
      if (latestOrder != null)
        {
          'number': latestOrder!['number'],
          'amount': latestOrder!['amount'],
          'time': latestOrder!['time'],
          'status': 'Preparing',
        },
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Order History'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          final isLatest =
              latestOrder != null && order['number'] == latestOrder!['number'];

          return Card(
            color: isLatest
                ? color.primary.withOpacity(0.08)
                : theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isLatest ? color.primary : Colors.transparent,
                width: 1.2,
              ),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ////// Left Section — Order Info //////
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${order['number']}',
                          style: TextStyle(
                            fontWeight: isLatest
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isLatest
                                ? color.primary
                                : theme.colorScheme.onBackground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Placed on ${order['time']} • ${order['status']}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),

                  ////// Right Section — Amount + Feedback //////
                  SizedBox(
                    height: 70, // prevents RenderFlex overflow
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '\$${order['amount'].toStringAsFixed(2)}',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (order['status'] == 'Delivered')
                          SizedBox(
                            height: 30,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const FeedbackScreen(),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: color.primary),
                                foregroundColor: color.primary,
                                padding: EdgeInsets.zero,
                                textStyle: theme.textTheme.bodySmall
                                    ?.copyWith(fontSize: 13),
                              ),
                              child: const Text('Feedback'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
