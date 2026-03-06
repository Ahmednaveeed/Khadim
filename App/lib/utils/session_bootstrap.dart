import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/token_storage.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../providers/cart_provider.dart';

class SessionBootstrap {
  static Future<void> run(BuildContext context) async {
    try {
      // 1) Check token exists
      final token = await TokenStorage.getToken();
      if (token == null) {
        _goLogin(context);
        return;
      }

      // 2) Validate session
      final me = await AuthService.me();
      final userId = (me['user_id'] ?? me['userId']).toString();

      // 3) Init cart
      await context.read<CartProvider>().initCart(userId);

      // 4) Go main
      _goMain(context);
    } on ApiException catch (e) {
      // Unauthorized -> clear and go login
      if (e.isUnauthorized) {
        await TokenStorage.clearToken();
        _goLogin(context);
        return;
      }

      // Any other API error -> also clear + go login (safe default for now)
      await TokenStorage.clearToken();
      _goLogin(context);
    } catch (_) {
      await TokenStorage.clearToken();
      _goLogin(context);
    }
  }

  static void _goLogin(BuildContext context) {
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  static void _goMain(BuildContext context) {
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/main');
  }
}