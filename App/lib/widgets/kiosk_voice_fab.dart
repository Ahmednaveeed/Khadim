import 'package:flutter/material.dart';
import 'package:khaadim/app_config.dart';
import 'package:khaadim/providers/dine_in_provider.dart';
import 'package:khaadim/widgets/mic_button.dart';
import 'package:khaadim/widgets/voice_nav_callbacks.dart';
import 'package:khaadim/widgets/voice_order_handler.dart';
import 'package:provider/provider.dart';

class KioskVoiceFab extends StatefulWidget {
  final bool visible;

  const KioskVoiceFab({
    super.key,
    this.visible = true,
  });

  @override
  State<KioskVoiceFab> createState() => _KioskVoiceFabState();
}

class _KioskVoiceFabState extends State<KioskVoiceFab> {
  late final VoiceOrderHandler _voiceHandler;

  @override
  void initState() {
    super.initState();

    _voiceHandler = VoiceOrderHandler();
    _voiceHandler.setNavCallbacks(
      VoiceNavCallbacks(
        switchTab: _navigateKioskTab,
        openMenuWithFilter: ({String? cuisine, String? category}) {
          _navigateToRoute(
            '/kiosk-menu',
            arguments: _buildMenuArgs(
              cuisine: cuisine,
              category: category,
            ),
          );
        },
        openCart: () {
          Navigator.pushNamed(context, '/kiosk-cart');
        },
        openCheckout: ({String paymentMethod = 'COD'}) {
          Navigator.pushNamed(context, '/kiosk-table');
        },
        openOrders: () {
          Navigator.pushNamed(context, '/kiosk-table');
        },
        openFavourites: () {
          Navigator.pushNamed(context, '/kiosk-home');
        },
        openRecommendations: () {
          Navigator.pushNamed(context, '/kiosk-home');
        },
        openDealsWithFilter: ({
          String? cuisineFilter,
          String? servingFilter,
          int? highlightDealId,
        }) {
          _navigateToRoute(
            '/kiosk-deals',
            arguments: _buildDealsArgs(
              cuisine: cuisineFilter,
              serving: servingFilter,
              highlightDealId: highlightDealId,
            ),
          );
        },
      ),
    );

    _voiceHandler.init().then((_) {
      if (!mounted || !AppConfig.isKiosk) {
        return;
      }

      final dineIn = context.read<DineInProvider>();
      _voiceHandler.setDineInAddItemCallback(
        (itemId, itemType, itemName, price, qty) async {
          dineIn.addItem(itemId, itemType, itemName, price, qty);
          return true;
        },
      );

      final sessionId = (dineIn.sessionId ?? '').trim();
      if (sessionId.isNotEmpty) {
        _voiceHandler.updateSessionId(sessionId);
      }
    });
  }

  void _navigateKioskTab(int index) {
    String route;
    switch (index) {
      case 1:
        route = '/kiosk-menu';
        break;
      case 2:
        route = '/kiosk-deals';
        break;
      case 3:
        route = '/kiosk-table';
        break;
      default:
        route = '/kiosk-home';
    }

    _navigateToRoute(route);
  }

  /// Push a kiosk route, replacing it when it's already the top screen
  /// so voice-driven filter updates apply to the current page instead of
  /// stacking another copy of the same screen.
  void _navigateToRoute(String target, {Object? arguments}) {
    if (!mounted) return;
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == target) {
      Navigator.pushReplacementNamed(
        context,
        target,
        arguments: arguments,
      );
    } else {
      Navigator.pushNamed(context, target, arguments: arguments);
    }
  }

  /// Build the arguments map the menu screen looks for. Returns null when
  /// there's nothing to pass so the screen falls back to default filters.
  Map<String, dynamic>? _buildMenuArgs({
    String? cuisine,
    String? category,
  }) {
    final args = <String, dynamic>{};
    if (cuisine != null && cuisine.trim().isNotEmpty) {
      args['cuisine'] = cuisine.trim();
    }
    if (category != null && category.trim().isNotEmpty) {
      args['category'] = category.trim();
    }
    return args.isEmpty ? null : args;
  }

  /// Build the arguments map the deals screen looks for. Same null-when-
  /// empty semantics as [_buildMenuArgs].
  Map<String, dynamic>? _buildDealsArgs({
    String? cuisine,
    String? serving,
    int? highlightDealId,
  }) {
    final args = <String, dynamic>{};
    if (cuisine != null && cuisine.trim().isNotEmpty) {
      args['cuisine'] = cuisine.trim();
    }
    if (serving != null && serving.trim().isNotEmpty) {
      args['serving'] = serving.trim();
    }
    if (highlightDealId != null && highlightDealId > 0) {
      args['highlight_deal_id'] = highlightDealId;
    }
    return args.isEmpty ? null : args;
  }

  @override
  void dispose() {
    _voiceHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible || !AppConfig.isKiosk) {
      return const SizedBox.shrink();
    }

    final dineIn = context.watch<DineInProvider>();
    final sessionId = (dineIn.sessionId ?? '').trim();
    if (sessionId.isNotEmpty) {
      _voiceHandler.updateSessionId(sessionId);
    }

    return AnimatedBuilder(
      animation: _voiceHandler,
      builder: (_, __) => MicButton(
        isRecording: _voiceHandler.isRecording,
        isProcessing: _voiceHandler.isProcessing,
        onPressDown: () => _voiceHandler.onMicDown(context),
        onPressUp: () => _voiceHandler.onMicUp(context),
        onCancel: _voiceHandler.onMicCancel,
      ),
    );
  }
}
