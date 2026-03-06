import 'package:flutter/material.dart';
import 'personal_info_screen.dart';
import 'package:khaadim/screens/orders/order_history_screen.dart';
import 'package:khaadim/screens/profile/settings_screen.dart';
import 'package:khaadim/screens/support/favorites_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ////// User Info Card ///////
            Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                  child: const Text("JD"),
                ),
                title: const Text("Sarim Rasheed"),
                subtitle: const Text("sarim@gmail.com"),
              ),
            ),
            const SizedBox(height: 20),

            ////// Profile Options ///////
            _buildProfileTile(
              context,
              Icons.person_outline,
              "Profile",
              "Manage your account",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
                );
              },
            ),
            _buildProfileTile(
              context,
              Icons.history,
              "Order History",
              "0 orders",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
                );
              },
            ),


            _buildProfileTile(
              context,
              Icons.favorite_border,
              "Favorites",
              "0 items",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                );
              },
            ),

            _buildProfileTile(
              context,
              Icons.settings_outlined,
              "Settings",
              "Preferences and more",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),





          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile(BuildContext context, IconData icon, String title,
      String subtitle, {VoidCallback? onTap}) {
    return Card(
      elevation: 0.3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.orangeAccent),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
