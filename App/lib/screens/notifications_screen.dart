import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    final notifications = [
      {
        'title': '50% Off Family Feast!',
        'body': 'Enjoy 50% off our Family Feast deal. Limited time only!',
        'time': '2 hours ago'
      },
      {
        'title': 'We miss you!',
        'body': 'Come back and enjoy 20% off your next order.',
        'time': '1 day ago'
      },
      {
        'title': 'New Menu Items',
        'body': 'Check out our new seasonal menu additions!',
        'time': '3 days ago'
      },
      {
        'title': 'Rate your last order!',
        'body': 'How was your meal? Let us know!',
        'time': '5 days ago'
      },
      {
        'title': 'Weekend Specials',
        'body': 'Free delivery on all orders this weekend.',
        'time': '1 week ago'
      },
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
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
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final n = notifications[index];
          return Card(
            color: index < 2
                ? color.primary.withOpacity(0.1)
                : theme.cardColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(Icons.local_offer_rounded,
                  color: color.primary, size: 28),
              title: Text(n['title']!,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              subtitle: Text(
                n['body']!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor),
              ),
              trailing: Text(
                n['time']!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor),
              ),
            ),
          );
        },
      ),
    );
  }
}
