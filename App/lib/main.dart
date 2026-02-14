import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'themes/app_theme.dart';

// Providers
import 'providers/cart_provider.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/main_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/offer_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/add_payment_screen.dart';
import 'screens/payment_method_screen.dart';
import 'screens/order_confirmation_screen.dart';
import 'screens/order_history_screen.dart';
import 'screens/test_urdu_tts.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const KhaadimApp(),
    ),
  );
}

class KhaadimApp extends StatelessWidget {
  const KhaadimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Khaadim',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      initialRoute: '/splash',

      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/main': (context) => const MainScreen(),
        '/menu': (context) => const MenuScreen(),
        '/offer': (context) => const OffersScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/cart': (context) => const CartScreen(),
        '/checkout': (context) => const CheckoutScreen(),
        '/payment_methods': (context) => const PaymentMethodsScreen(),
        '/add_payment': (context) => const AddPaymentScreen(),
        '/order_history': (context) => const OrderHistoryScreen(),
        '/ttsTest': (context) => const TestUrduTTSPage(),

        '/orderConfirmation': (context) => const OrderConfirmationScreen(
          orderNumber: 'N/A',
          totalAmount: 0.0,
        ),
      },

      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const SplashScreen(),
        );
      },
    );
  }
}
