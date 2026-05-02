import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:khaadim/app_config.dart';
import 'package:khaadim/providers/dine_in_provider.dart';
import 'package:khaadim/screens/dine_in/kiosk_bottom_nav.dart';
import 'package:khaadim/services/dine_in_service.dart';
import 'package:khaadim/widgets/kiosk_voice_fab.dart';
import 'package:provider/provider.dart';

String _formatClockTime(DateTime? time) {
  if (time == null) {
    return '--';
  }

  final hour24 = time.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = hour24 >= 12 ? 'PM' : 'AM';

  return '$hour12:$minute $period';
}

String _formatDuration(Duration duration) {
  final totalMinutes = duration.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;

  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }

  return '${minutes}m';
}

String _money(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}

String _maskedCard(String rawCardNumber) {
  final digitsOnly = rawCardNumber.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.length < 4) {
    return '****';
  }

  final last4 = digitsOnly.substring(digitsOnly.length - 4);
  return '**** **** **** $last4';
}

class MyTableScreen extends StatefulWidget {
  const MyTableScreen({super.key});

  @override
  State<MyTableScreen> createState() => _MyTableScreenState();
}

class _MyTableScreenState extends State<MyTableScreen> {
  final DineInService _dineInService = DineInService();

  bool _isLoadingRounds = true;
  String? _roundsError;
  List<_SessionRound> _rounds = <_SessionRound>[];

  Timer? _durationTicker;
  Timer? _paymentSettlementPoller;

  bool _isPaymentResetInProgress = false;
  bool _isSettlementPopupVisible = false;

  // Set once when the screen opens with an auto-payment intent (voice-driven)
  // so we can trigger the matching payment flow after rounds load without
  // re-firing on rebuilds.
  String? _pendingAutoPaymentMethod;
  bool _autoPaymentTriggered = false;

  @override
  void initState() {
    super.initState();

    _durationTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeRouteArguments();
      _fetchRounds();
    });
  }

  void _consumeRouteArguments() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final method = (args['auto_payment'] ?? '').toString().trim().toLowerCase();
      if (method == 'card' || method == 'cash') {
        _pendingAutoPaymentMethod = method;
      }
    }
  }

  Future<void> _maybeAutoOpenPaymentFlow() async {
    if (_autoPaymentTriggered) return;
    final method = _pendingAutoPaymentMethod;
    if (method == null) return;

    // Guard: only auto-open when there's something to pay for. If not, speak
    // nothing extra — the voice service already spoke the eligibility reason.
    if (_isLoadingRounds || _roundsError != null) return;
    if (_rounds.isEmpty || !_hasPendingPayment) return;

    _autoPaymentTriggered = true;
    _pendingAutoPaymentMethod = null;

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PaymentDetailsScreen(
          loadRounds: _loadRoundsFromApi,
          notifyWaiter: _notifyWaiter,
          onSessionSettled: _handleSessionSettledAndReset,
          autoPaymentMethod: method,
        ),
      ),
    );

    if (!mounted) return;
    await _fetchRounds();
  }

  @override
  void dispose() {
    _durationTicker?.cancel();
    _paymentSettlementPoller?.cancel();
    super.dispose();
  }

  void _startPaymentSettlementPolling() {
    if (_paymentSettlementPoller != null) {
      return;
    }

    _paymentSettlementPoller = Timer.periodic(const Duration(seconds: 4), (_) {
      _pollSettlementStatus();
    });
  }

  void _stopPaymentSettlementPolling() {
    _paymentSettlementPoller?.cancel();
    _paymentSettlementPoller = null;
  }

  void _syncPaymentSettlementPolling(List<_SessionRound> rounds) {
    final hasPendingPayment = rounds.any((round) => !round.isPaid);
    if (hasPendingPayment) {
      _startPaymentSettlementPolling();
      return;
    }

    _stopPaymentSettlementPolling();
  }

  Future<bool> _tryStartFreshSession(DineInProvider dineIn) async {
    return dineIn.loginOrStartSessionFromCache(_dineInService);
  }

  Future<void> _handleSessionSettledAndReset({required String message}) async {
    if (!mounted || _isPaymentResetInProgress) {
      return;
    }

    setState(() {
      _isPaymentResetInProgress = true;
    });

    context.read<DineInProvider>().resetWaiterState();
    _stopPaymentSettlementPolling();

    _isSettlementPopupVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text('Payment Confirmed'),
          content: Text(message),
        );
      },
    ).whenComplete(() {
      _isSettlementPopupVisible = false;
    });

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) {
      return;
    }

    if (_isSettlementPopupVisible) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (!mounted) {
      return;
    }

    final dineIn = context.read<DineInProvider>();
    await dineIn.clearSessionKeepTableLock();
    if (!mounted) {
      return;
    }

    // Guest taps START SESSION on the home resting screen to begin the next session.

    // Always return to kiosk home after payment — never the PIN screen.
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/kiosk-home',
      (_) => false,
    );
  }

  Future<void> _pollSettlementStatus() async {
    if (!mounted || _isLoadingRounds || _isPaymentResetInProgress) {
      return;
    }

    final dineIn = context.read<DineInProvider>();
    final sessionId = dineIn.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      _stopPaymentSettlementPolling();
      return;
    }

    try {
      final previousHasPending = _rounds.any((round) => !round.isPaid);
      final parsed = await _loadRoundsFromApi();
      if (!mounted || _isPaymentResetInProgress) {
        return;
      }

      final hasPendingNow = parsed.any((round) => !round.isPaid);
      final justSettled =
          previousHasPending && parsed.isNotEmpty && !hasPendingNow;

      setState(() {
        _rounds = parsed;
        _roundsError = null;
      });

      _syncPaymentSettlementPolling(parsed);

      if (justSettled) {
        await _handleSessionSettledAndReset(
          message: 'Thanks for dining in. Clearing your session now...',
        );
      }
    } catch (_) {
      // Keep polling to handle transient failures.
    }
  }

  double get _sessionTotal {
    return _rounds.fold<double>(0.0, (sum, round) => sum + round.roundTotal);
  }

  bool get _hasPendingPayment {
    return _rounds.any((round) => !round.isPaid);
  }

  int get _pendingRoundCount {
    return _rounds.where((round) => !round.isPaid).length;
  }

  Future<List<_SessionRound>> _loadRoundsFromApi() async {
    final dineIn = Provider.of<DineInProvider>(context, listen: false);
    final sessionId = dineIn.sessionId;

    if (sessionId == null || sessionId.isEmpty) {
      throw Exception('No active dine-in session found.');
    }

    final roundsRaw = await _dineInService.fetchSessionOrders(
      sessionId,
      token: dineIn.token,
    );

    final parsed = <_SessionRound>[];
    for (var i = 0; i < roundsRaw.length; i++) {
      parsed.add(_SessionRound.fromMap(roundsRaw[i], i));
    }

    parsed.sort((a, b) => a.roundNumber.compareTo(b.roundNumber));
    return parsed;
  }

  Future<void> _fetchRounds() async {
    setState(() {
      _isLoadingRounds = true;
      _roundsError = null;
    });

    try {
      final parsed = await _loadRoundsFromApi();
      if (!mounted) return;
      setState(() {
        _rounds = parsed;
        _isLoadingRounds = false;
      });
      _syncPaymentSettlementPolling(parsed);
      await _maybeAutoOpenPaymentFlow();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingRounds = false;
        _roundsError = e.toString().replaceFirst('Exception: ', '');
        _rounds = <_SessionRound>[];
      });
      _stopPaymentSettlementPolling();
    }
  }

  Future<void> _notifyWaiter({bool forCashPayment = false}) async {
    if (!mounted) return;

    final dineIn = context.read<DineInProvider>();
    try {
      await dineIn.notifyWaiter(forCashPayment: forCashPayment);
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openOrderHistoryScreen(DateTime startedAt) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _OrderHistoryDetailsScreen(
          startedAt: startedAt,
          loadRounds: _loadRoundsFromApi,
        ),
      ),
    );

    if (!mounted) return;
    await _fetchRounds();
  }

  Future<void> _openPaymentScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PaymentDetailsScreen(
          loadRounds: _loadRoundsFromApi,
          notifyWaiter: _notifyWaiter,
          onSessionSettled: _handleSessionSettledAndReset,
        ),
      ),
    );

    if (!mounted) return;
    await _fetchRounds();
  }

  Future<void> _confirmEndSession(String tableNumber) async {
    final canEnd =
        !_isLoadingRounds && _roundsError == null && !_hasPendingPayment;
    if (!canEnd) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please settle pending payment before ending session.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('End Session?'),
          content: Text(
            'This will log out Table $tableNumber.\n'
            'Make sure your bill is settled first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('End Session'),
            ),
          ],
        );
      },
    );

    if (shouldEnd != true || !mounted) return;

    final dineIn = Provider.of<DineInProvider>(context, listen: false);
    final sessionId = dineIn.sessionId;

    if (sessionId != null && sessionId.isNotEmpty) {
      try {
        await _dineInService.endSession(sessionId, token: dineIn.token);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    await dineIn.clearSessionKeepTableLock();

    if (!mounted) return;

    // Try to stay logged into the table (without starting a session) 
    // so the kiosk doesn't need a PIN re-entry.
    bool stayLoggedIn = false;
    try {
      stayLoggedIn = await _tryStartFreshSession(dineIn);
    } catch (_) {
      stayLoggedIn = false;
    }

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      stayLoggedIn ? '/kiosk-home' : '/kiosk-login',
      (_) => false,
    );
  }

  Widget _buildSessionInfoCard(
    ThemeData theme,
    String tableNumber,
    DateTime startedAt,
  ) {
    final duration = DateTime.now().difference(startedAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Table $tableNumber',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Session started at: ${_formatClockTime(startedAt)}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Duration: ${_formatDuration(duration)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigateCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badge,
    Color? badgeColor,
  }) {
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? theme.colorScheme.primary).withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: badgeColor ?? theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.hintColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaiterRequestSection(ThemeData theme) {
    // Watch the provider so voice-triggered state changes rebuild this card
    // automatically, just like the manual button path.
    final waiterState = context.watch<DineInProvider>().waiterRequestState;

    String? waiterStatusText;
    if (waiterState == WaiterRequestState.notified) {
      waiterStatusText = 'Waiter has been notified!';
    } else if (waiterState == WaiterRequestState.acknowledged) {
      waiterStatusText =
          'Waiter has received your request and is coming at your table.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: _isPaymentResetInProgress ? null : _notifyWaiter,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
          child: const Text('CALL WAITER'),
        ),
        if (waiterStatusText != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              waiterStatusText,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (waiterState == WaiterRequestState.notified)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Waiting for kitchen acknowledgement...',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildEndSessionSection(ThemeData theme, String tableNumber) {
    final canEndSession =
        !_isLoadingRounds && _roundsError == null && !_hasPendingPayment;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!canEndSession)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _isLoadingRounds
                    ? 'Checking payment status before ending session.'
                    : 'Settle pending payment before ending session.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          TextButton(
            onPressed: canEndSession
                ? () => _confirmEndSession(tableNumber)
                : null,
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              foregroundColor: Colors.red,
            ),
            child: const Text('END SESSION'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dineIn = Provider.of<DineInProvider>(context);

    final tableNumber = (dineIn.tableNumber ?? '').trim().isEmpty
        ? '--'
        : dineIn.tableNumber!.trim();
    final startedAt = dineIn.startedAt ?? DateTime.now();

    final historySubtitle = _isLoadingRounds
        ? 'Loading session rounds...'
        : _roundsError != null
        ? 'Unable to load rounds. Tap to retry.'
        : _rounds.isEmpty
        ? 'No rounds yet. Tap to view details.'
        : '${_rounds.length} round${_rounds.length == 1 ? '' : 's'}  |  Session total Rs ${_money(_sessionTotal)}';

    final paymentSubtitle = _isLoadingRounds
        ? 'Checking due amount...'
        : _roundsError != null
        ? 'Unable to verify payment state.'
        : _hasPendingPayment
        ? 'Rs ${_money(_sessionTotal)} due in $_pendingRoundCount round${_pendingRoundCount == 1 ? '' : 's'}'
        : 'All rounds are paid';

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppConfig.isKiosk ? 'My Table' : 'Session'),
          actions: [
            IconButton(
              onPressed: _fetchRounds,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh session',
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _fetchRounds,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSessionInfoCard(theme, tableNumber, startedAt),
              const SizedBox(height: 16),
              _buildNavigateCard(
                theme,
                icon: Icons.receipt_long,
                title: 'Order History',
                subtitle: historySubtitle,
                badge: _roundsError != null
                    ? 'Retry'
                    : _rounds.isNotEmpty
                    ? '${_rounds.length}'
                    : null,
                badgeColor: _roundsError != null
                    ? Colors.red.shade700
                    : theme.colorScheme.primary,
                onTap: () => _openOrderHistoryScreen(startedAt),
              ),
              const SizedBox(height: 12),
              _buildNavigateCard(
                theme,
                icon: Icons.payments_outlined,
                title: 'Payment',
                subtitle: paymentSubtitle,
                badge: _hasPendingPayment ? 'Pending' : 'Paid',
                badgeColor: _hasPendingPayment
                    ? Colors.orange.shade800
                    : Colors.green.shade700,
                onTap: _openPaymentScreen,
              ),
              const SizedBox(height: 14),
              _buildWaiterRequestSection(theme),
              const SizedBox(height: 18),
            ],
          ),
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildEndSessionSection(theme, tableNumber),
            const KioskBottomNav(currentIndex: 3),
          ],
        ),
        floatingActionButton:
            AppConfig.isKiosk ? const KioskVoiceFab() : null,
      ),
    );
  }
}

class _OrderHistoryDetailsScreen extends StatefulWidget {
  final DateTime startedAt;
  final Future<List<_SessionRound>> Function() loadRounds;

  const _OrderHistoryDetailsScreen({
    required this.startedAt,
    required this.loadRounds,
  });

  @override
  State<_OrderHistoryDetailsScreen> createState() =>
      _OrderHistoryDetailsScreenState();
}

class _OrderHistoryDetailsScreenState
    extends State<_OrderHistoryDetailsScreen> {
  bool _isLoading = true;
  String? _error;
  List<_SessionRound> _rounds = <_SessionRound>[];

  double get _sessionTotal {
    return _rounds.fold<double>(0.0, (sum, round) => sum + round.roundTotal);
  }

  @override
  void initState() {
    super.initState();
    _refreshRounds();
  }

  Future<void> _refreshRounds() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rounds = await widget.loadRounds();
      if (!mounted) return;
      setState(() {
        _rounds = rounds;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
        _rounds = <_SessionRound>[];
      });
    }
  }

  void _openTrackingForRound(_SessionRound round) {
    final orderId = round.orderId;
    if (orderId == null || orderId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tracking is not available for this round yet.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final sessionId = context.read<DineInProvider>().sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active session available for tracking.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _DineInOrderTrackingScreen(sessionId: sessionId, orderId: orderId),
      ),
    );
  }

  Widget _buildRoundCard(ThemeData theme, _SessionRound round) {
    final header =
        'Round ${round.roundNumber}  -   ${_formatClockTime(round.createdAt ?? widget.startedAt)}  -   Rs ${_money(round.roundTotal)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        title: Text(
          header,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: round.isPaid
                      ? Colors.green.withValues(alpha: 0.14)
                      : Colors.orange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  round.isPaid ? 'Paid' : 'To Be Paid',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: round.isPaid
                        ? Colors.green.shade700
                        : Colors.orange.shade800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () => _openTrackingForRound(round),
                child: Text(
                  'Track ->',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        children: [
          if (round.items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('No item details available for this round.'),
              ),
            )
          else
            ...round.items.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(item.name, style: theme.textTheme.bodyMedium),
                    ),
                    Text(
                      'x${item.quantity}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Rs ${_money(item.price)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _refreshRounds,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    } else if (_rounds.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No orders yet. Browse the menu to get started!',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/kiosk-menu'),
                child: const Text('Browse Menu'),
              ),
            ],
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _refreshRounds,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Session Total',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Rs ${_money(_sessionTotal)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ..._rounds.map((round) => _buildRoundCard(theme, round)),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        actions: [
          IconButton(
            onPressed: _refreshRounds,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: body,
      floatingActionButton:
          AppConfig.isKiosk ? const KioskVoiceFab() : null,
    );
  }
}

class _PaymentDetailsScreen extends StatefulWidget {
  final Future<List<_SessionRound>> Function() loadRounds;
  final Future<void> Function({bool forCashPayment}) notifyWaiter;
  final Future<void> Function({required String message}) onSessionSettled;

  /// Optional voice-driven auto-trigger: when set to 'card' or 'cash', the
  /// screen will automatically fire the matching handler after the first
  /// data load so the user doesn't have to tap. All existing manual flows
  /// (dialogs, add-card screen, settlement popup) still run.
  final String? autoPaymentMethod;

  const _PaymentDetailsScreen({
    required this.loadRounds,
    required this.notifyWaiter,
    required this.onSessionSettled,
    this.autoPaymentMethod,
  });

  @override
  State<_PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<_PaymentDetailsScreen> {
  bool _isLoading = true;
  String? _error;
  List<_SessionRound> _rounds = <_SessionRound>[];
  bool _autoTriggered = false;

  double get _sessionTotal {
    return _rounds.fold<double>(0.0, (sum, round) => sum + round.roundTotal);
  }

  bool get _hasPendingPayment {
    return _rounds.any((round) => !round.isPaid);
  }

  bool get _hasOrders {
    return _rounds.isNotEmpty;
  }

  bool get _allRoundsCompleted {
    if (_rounds.isEmpty) {
      return false;
    }
    return _rounds.every((round) => round.isCompleted);
  }

  @override
  void initState() {
    super.initState();
    _refreshRounds();
  }

  Future<void> _refreshRounds() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rounds = await widget.loadRounds();
      if (!mounted) return;
      setState(() {
        _rounds = rounds;
        _isLoading = false;
      });
      await _maybeAutoTriggerPayment();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
        _rounds = <_SessionRound>[];
      });
    }
  }

  Future<void> _maybeAutoTriggerPayment() async {
    if (_autoTriggered) return;
    final method = widget.autoPaymentMethod;
    if (method == null) return;

    _autoTriggered = true;

    // Respect the same eligibility rules the tap-handlers enforce; if the
    // guest can't pay yet, let the tap handlers explain why via SnackBars
    // so the visible state exactly matches what they'd see tapping the
    // card themselves.
    if (!_hasOrders || !_hasPendingPayment || !_allRoundsCompleted) {
      if (method == 'card') {
        await _handleCardPayment();
      } else if (method == 'cash') {
        await _handleCashPayment();
      }
      return;
    }

    if (method == 'card') {
      await _handleCardPayment();
    } else if (method == 'cash') {
      await _handleCashPayment();
    }
  }

  Future<void> _openAddCardScreen() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const _SessionAddCardScreen()),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Card saved for this session'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {});
    }
  }

  Future<void> _handleCardPayment() async {
    if (!_hasOrders) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No orders found for this session yet.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_hasPendingPayment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All rounds are already paid.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_allRoundsCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment can be completed only after all rounds are marked completed.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final dineIn = Provider.of<DineInProvider>(context, listen: false);
    if (dineIn.sessionCard == null) {
      await _openAddCardScreen();
      if (!mounted) return;
      if (Provider.of<DineInProvider>(context, listen: false).sessionCard ==
          null) {
        return;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Pay by Card?'),
          content: Text(
            'Proceed with card payment for Rs ${_money(_sessionTotal)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Pay'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final sessionId = dineIn.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active dine-in session found.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final response = await DineInService().settleSessionPayment(
        sessionId,
        'card',
        token: dineIn.token,
      );
      if (!mounted) return;

      final backendMessage = (response['message'] ?? '').toString().trim();
      final popupMessage = backendMessage.isEmpty
          ? 'Thanks for dining in. Clearing your session now...'
          : 'Thanks for dining in.\n$backendMessage\n\nClearing your session now...';

      await widget.onSessionSettled(message: popupMessage);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleCashPayment() async {
    if (!_hasOrders || !_hasPendingPayment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pending payment available for cash request.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_allRoundsCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cash request is available only after all rounds are marked completed.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Notify kitchen only. Session ends when staff confirm cash on the kitchen
    // dashboard (orders marked paid); `_pollSettlementStatus` on My Table then
    // triggers the same flow as card: dialog + clear session + `/kiosk-home`.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Pay by Cash?'),
          content: Text(
            'Kitchen will be notified to collect Rs ${_money(_sessionTotal)} in cash. '
            'Your session will end after they confirm payment on the dashboard.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Notify kitchen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await widget.notifyWaiter(forCashPayment: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kitchen notified. You will return to the home screen when payment is confirmed.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildPaymentActionTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1.0 : 0.55,
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: theme.hintColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dineIn = Provider.of<DineInProvider>(context);
    final card = dineIn.sessionCard;

    Widget body;

    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _refreshRounds,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _refreshRounds,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _hasPendingPayment ? 'Amount Due' : 'Payment Status',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _hasPendingPayment
                        ? 'Rs ${_money(_sessionTotal)}'
                        : 'All paid',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _hasPendingPayment
                          ? Colors.orange.shade800
                          : Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (card != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saved session card',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_maskedCard(card.cardNumber)}    ${card.expiry}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            _buildPaymentActionTile(
              theme: theme,
              icon: Icons.credit_card,
              title: 'Pay by Card',
              subtitle: !_allRoundsCompleted && _hasOrders
                  ? 'Available after all rounds are completed'
                  : card == null
                  ? 'Add a card first, then complete payment'
                  : 'Use saved session card to proceed',
              onTap: _hasOrders && _hasPendingPayment && _allRoundsCompleted
                  ? _handleCardPayment
                  : null,
            ),
            const SizedBox(height: 10),
            _buildPaymentActionTile(
              theme: theme,
              icon: Icons.payments,
              title: 'Pay by Cash',
              subtitle: !_allRoundsCompleted && _hasOrders
                  ? 'Available after all rounds are completed'
                  : 'Waiter will be notified for cash collection',
              onTap: _hasOrders && _hasPendingPayment && _allRoundsCompleted
                  ? _handleCashPayment
                  : null,
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _openAddCardScreen,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 0,
                  ),
                ),
                child: const Text('Add card for this session'),
              ),
            ),
            if (!_hasOrders)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Place at least one round before requesting payment.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (_hasOrders && !_hasPendingPayment)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'No payment is pending for this session.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (_hasOrders && _hasPendingPayment && !_allRoundsCompleted)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Payment unlocks when all rounds are completed in kitchen.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        actions: [
          IconButton(
            onPressed: _refreshRounds,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _DineInOrderTrackingScreen extends StatefulWidget {
  final String sessionId;
  final int orderId;

  const _DineInOrderTrackingScreen({
    required this.sessionId,
    required this.orderId,
  });

  @override
  State<_DineInOrderTrackingScreen> createState() =>
      _DineInOrderTrackingScreenState();
}

class _DineInOrderTrackingScreenState
    extends State<_DineInOrderTrackingScreen> {
  final DineInService _dineInService = DineInService();

  bool _loading = true;
  String? _error;
  String _status = 'confirmed';
  int _estimatedPrepTimeMinutes = 15;
  int _roundNumber = 0;
  String? _paymentStatus;
  DateTime? _createdAt;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadTracking(showLoader: true);
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadTracking(showLoader: false);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTracking({required bool showLoader}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final token = context.read<DineInProvider>().token;
      final data = await _dineInService.fetchSessionOrderTracking(
        widget.sessionId,
        widget.orderId,
        token: token,
      );

      if (!mounted) return;

      final parsedStatus = (data['status'] ?? _status).toString().toLowerCase();
      final parsedPrep = _SessionRound._asInt(
        data['estimated_prep_time_minutes'],
      );
      final parsedRound = _SessionRound._asInt(data['round_number']);
      final parsedCreatedAt = _SessionRound._asDateTime(data['created_at']);

      setState(() {
        _status = parsedStatus;
        _estimatedPrepTimeMinutes = parsedPrep ?? _estimatedPrepTimeMinutes;
        _roundNumber = parsedRound ?? _roundNumber;
        _paymentStatus = data['payment_status']?.toString();
        _createdAt = parsedCreatedAt;
        _error = null;
        _loading = false;
      });

      if (_status == 'completed') {
        _pollTimer?.cancel();
      }
    } catch (e) {
      if (!mounted) return;

      if (showLoader) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  String _displayTime(String status, int storedMinutes) {
    final s = status.toLowerCase();
    final base = storedMinutes > 0 ? storedMinutes : 15;

    switch (s) {
      case 'confirmed':
      case 'in_kitchen':
        return '$base mins';
      case 'preparing':
        final left = (storedMinutes - 3).clamp(1, 99);
        return '$left mins';
      case 'ready':
        final left = (base ~/ 6).clamp(1, 99);
        return '$left min${left == 1 ? '' : 's'}';
      case 'completed':
        return '0 mins';
      default:
        return '$base mins';
    }
  }

  double _progressForStatus(String status) {
    final s = status.toLowerCase();
    switch (s) {
      case 'confirmed':
      case 'in_kitchen':
        return 0.15;
      case 'preparing':
        return 0.45;
      case 'ready':
        return 0.75;
      case 'completed':
        return 1.0;
      default:
        return 0.1;
    }
  }

  bool _isDone(String currentStatus, List<String> states) {
    return states.contains(currentStatus.toLowerCase());
  }

  bool _isCurrent(String currentStatus, List<String> states) {
    return states.contains(currentStatus.toLowerCase());
  }

  Widget _buildStatusRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool done,
    required bool inProgress,
  }) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: done
            ? Colors.green
            : inProgress
            ? color.primary
            : theme.hintColor,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: done
              ? Colors.green
              : inProgress
              ? color.primary
              : theme.hintColor,
        ),
      ),
      trailing: done
          ? const Icon(Icons.check, color: Colors.green)
          : inProgress
          ? Text(
              'In Progress',
              style: theme.textTheme.bodySmall?.copyWith(color: color.primary),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => _loadTracking(showLoader: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    } else {
      body = SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _roundNumber > 0
                          ? 'Order #${widget.orderId}  |  Round $_roundNumber'
                          : 'Order #${widget.orderId}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_createdAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Placed at ${_formatClockTime(_createdAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      'Estimated Prep Time',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time, color: color.primary, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _displayTime(_status, _estimatedPrepTimeMinutes),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: color.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _progressForStatus(_status),
                      backgroundColor: color.primary.withValues(alpha: 0.2),
                      color: color.primary,
                      minHeight: 4,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Status: ${_status.toUpperCase()}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: color.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_paymentStatus != null &&
                        _paymentStatus!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Payment: ${_paymentStatus!.replaceAll('_', ' ').toUpperCase()}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Column(
                  children: [
                    _buildStatusRow(
                      context,
                      icon: Icons.check_circle,
                      title: 'Order Confirmed',
                      done: _isDone(_status, [
                        'confirmed',
                        'in_kitchen',
                        'preparing',
                        'ready',
                        'completed',
                      ]),
                      inProgress: _isCurrent(_status, ['confirmed']),
                    ),
                    _buildStatusRow(
                      context,
                      icon: Icons.local_fire_department,
                      title: 'Preparing',
                      done: _isDone(_status, [
                        'preparing',
                        'ready',
                        'completed',
                      ]),
                      inProgress: _isCurrent(_status, [
                        'in_kitchen',
                        'preparing',
                      ]),
                    ),
                    _buildStatusRow(
                      context,
                      icon: Icons.restaurant,
                      title: 'Ready',
                      done: _isDone(_status, ['ready', 'completed']),
                      inProgress: _isCurrent(_status, ['ready']),
                    ),
                    _buildStatusRow(
                      context,
                      icon: Icons.verified,
                      title: 'Completed',
                      done: _isDone(_status, ['completed']),
                      inProgress: false,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Order'),
        actions: [
          IconButton(
            onPressed: () => _loadTracking(showLoader: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _SessionAddCardScreen extends StatefulWidget {
  const _SessionAddCardScreen();

  @override
  State<_SessionAddCardScreen> createState() => _SessionAddCardScreenState();
}

class _SessionAddCardScreenState extends State<_SessionAddCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _nameController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  bool _saving = false;

  bool _luhn(String number) {
    final digits = number.replaceAll(' ', '');
    if (digits.length < 13 || digits.length > 19) return false;

    var sum = 0;
    var alternate = false;

    for (var i = digits.length - 1; i >= 0; i--) {
      final parsed = int.tryParse(digits[i]);
      if (parsed == null) return false;

      var n = parsed;
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }

    return sum % 10 == 0;
  }

  String _detectBrand(String number) {
    final d = number.replaceAll(' ', '');
    if (d.startsWith('4')) return 'Visa';
    if (d.startsWith('5')) return 'Mastercard';
    if (d.startsWith('3')) return 'Amex';
    return 'Card';
  }

  IconData _brandIcon(String brand) {
    switch (brand) {
      case 'Visa':
      case 'Mastercard':
      case 'Amex':
        return Icons.credit_card;
      default:
        return Icons.credit_card_outlined;
    }
  }

  Color _brandColor(String brand) {
    switch (brand) {
      case 'Visa':
        return const Color(0xFF1A1F71);
      case 'Mastercard':
        return const Color(0xFFEB001B);
      case 'Amex':
        return const Color(0xFF007BC1);
      default:
        return Colors.grey;
    }
  }

  String? _validateExpiry(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter expiry date';

    final parts = value.split('/');
    if (parts.length != 2) return 'Use MM/YY format';

    final month = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);

    if (month == null || year == null) return 'Use MM/YY format';
    if (month < 1 || month > 12) return 'Invalid expiry month';

    final now = DateTime.now();
    final fourDigitYear = 2000 + year;

    final expiryDate = DateTime(fourDigitYear, month + 1, 0);
    final lastMomentOfMonth = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
      23,
      59,
      59,
    );

    if (lastMomentOfMonth.isBefore(now)) {
      return 'Card is expired';
    }

    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final cardRaw = _cardNumberController.text.replaceAll(' ', '').trim();

    setState(() => _saving = true);

    Provider.of<DineInProvider>(context, listen: false).saveSessionCard(
      CardDetails(
        cardNumber: cardRaw,
        expiry: _expiryController.text.trim(),
        cvv: _cvvController.text.trim(),
      ),
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _nameController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = _detectBrand(_cardNumberController.text);
    final rawNum = _cardNumberController.text.replaceAll(' ', '');

    final masked = rawNum.isEmpty
        ? '**** **** **** ****'
        : rawNum
              .padRight(16, '*')
              .replaceAllMapped(RegExp(r'.{4}'), (m) => '${m.group(0)} ')
              .trim();

    final displayName = _nameController.text.isEmpty
        ? 'CARDHOLDER NAME'
        : _nameController.text.toUpperCase();

    final displayExpiry = _expiryController.text.isEmpty
        ? 'MM/YY'
        : _expiryController.text;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Add Card for Session')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: 190,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _brandColor(brand).withValues(alpha: 0.85),
                      Colors.black87,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _brandColor(brand).withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            brand,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          Icon(
                            _brandIcon(brand),
                            color: Colors.white70,
                            size: 32,
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        masked,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          letterSpacing: 3,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CARD HOLDER',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'EXPIRES',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                displayExpiry,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _cardNumberController,
                      decoration: InputDecoration(
                        labelText: 'Card Number',
                        hintText: '1234 5678 9012 3456',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _SessionCardNumberFormatter(),
                      ],
                      maxLength: 19,
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        final digits = (v ?? '').replaceAll(' ', '').trim();

                        if (digits.isEmpty) {
                          return 'Enter card number';
                        }

                        if (!RegExp(r'^[0-9]+$').hasMatch(digits)) {
                          return 'Card number must contain digits only';
                        }

                        if (digits.length < 13 || digits.length > 19) {
                          return 'Card number must be 13 to 19 digits';
                        }

                        if (!_luhn(digits)) {
                          return 'Invalid card number';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Cardholder Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                      ),
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        if (v == null || v.trim().length < 3) {
                          return 'Enter a valid name (min 3 characters)';
                        }
                        if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(v.trim())) {
                          return 'Name must contain letters and spaces only';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _expiryController,
                            decoration: InputDecoration(
                              labelText: 'Expiry Date',
                              hintText: 'MM/YY',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              _SessionExpiryFormatter(),
                            ],
                            maxLength: 5,
                            onChanged: (_) => setState(() {}),
                            validator: _validateExpiry,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _cvvController,
                            decoration: InputDecoration(
                              labelText: 'CVV',
                              hintText: '123',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            maxLength: 3,
                            obscureText: true,
                            validator: (v) {
                              final brand = _detectBrand(
                                _cardNumberController.text,
                              );
                              final requiredLength = brand == 'Amex' ? 4 : 3;

                              if (v == null || v.trim().isEmpty) {
                                return 'Enter CVV';
                              }

                              if (v.length != requiredLength) {
                                return 'CVV must be $requiredLength digits';
                              }

                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save for Session',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionCardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return newValue.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

class _SessionExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll('/', '');
    if (digits.length >= 3) {
      final str = '${digits.substring(0, 2)}/${digits.substring(2)}';
      return newValue.copyWith(
        text: str,
        selection: TextSelection.collapsed(offset: str.length),
      );
    }
    return newValue;
  }
}

class _SessionRound {
  final int? orderId;
  final int roundNumber;
  final DateTime? createdAt;
  final double roundTotal;
  final String kitchenStatus;
  final bool isPaid;
  final List<_RoundItem> items;

  const _SessionRound({
    required this.orderId,
    required this.roundNumber,
    required this.createdAt,
    required this.roundTotal,
    required this.kitchenStatus,
    required this.isPaid,
    required this.items,
  });

  factory _SessionRound.fromMap(Map<String, dynamic> data, int index) {
    final roundItemsRaw = data['items'];
    final parsedItems = <_RoundItem>[];
    if (roundItemsRaw is List) {
      for (final raw in roundItemsRaw) {
        if (raw is Map) {
          parsedItems.add(_RoundItem.fromMap(Map<String, dynamic>.from(raw)));
        }
      }
    }

    final computedTotal = parsedItems.fold<double>(
      0.0,
      (sum, item) => sum + (item.price * item.quantity),
    );

    final rawTotal =
        _asDouble(data['round_total']) ??
        _asDouble(data['total']) ??
        _asDouble(data['total_price']) ??
        _asDouble(data['amount']) ??
        computedTotal;

    final parsedKitchenStatus = (data['kitchen_status'] ?? data['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    return _SessionRound(
      orderId: _asInt(data['order_id'] ?? data['id']),
      roundNumber: _asInt(data['round_number']) ?? (index + 1),
      createdAt: _asDateTime(
        data['created_at'] ?? data['ordered_at'] ?? data['time'],
      ),
      roundTotal: rawTotal,
      kitchenStatus: parsedKitchenStatus,
      isPaid: _isRoundPaid(data),
      items: parsedItems,
    );
  }

  bool get isCompleted {
    return kitchenStatus == 'completed' || kitchenStatus == 'served';
  }

  static bool _isRoundPaid(Map<String, dynamic> data) {
    final paidFlag = data['is_paid'] ?? data['paid'];
    if (paidFlag is bool) {
      return paidFlag;
    }

    final paymentStatus = (data['payment_status'] ?? '')
        .toString()
        .toLowerCase();
    if (paymentStatus == 'paid' || paymentStatus == 'settled') {
      return true;
    }

    final status = (data['status'] ?? '').toString().toLowerCase();
    return status == 'paid' || status == 'settled';
  }

  static int? _asInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse((raw ?? '').toString());
  }

  static double? _asDouble(dynamic raw) {
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    if (raw is num) return raw.toDouble();
    return double.tryParse((raw ?? '').toString());
  }

  static DateTime? _asDateTime(dynamic raw) {
    if (raw is DateTime) return raw;
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}

class _RoundItem {
  final String name;
  final int quantity;
  final double price;

  const _RoundItem({
    required this.name,
    required this.quantity,
    required this.price,
  });

  factory _RoundItem.fromMap(Map<String, dynamic> data) {
    final quantity = _asInt(data['quantity']) ?? 1;
    final lineTotal = _asDouble(data['line_total']) ?? 0.0;
    final unitPrice =
        _asDouble(data['price']) ??
        _asDouble(data['unit_price']) ??
        _asDouble(data['unit_price_snapshot']) ??
        (quantity > 0 ? lineTotal / quantity : 0.0);

    return _RoundItem(
      name:
          (data['item_name'] ?? data['name'] ?? data['name_snapshot'] ?? 'Item')
              .toString(),
      quantity: quantity,
      price: unitPrice,
    );
  }

  static int? _asInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse((raw ?? '').toString());
  }

  static double? _asDouble(dynamic raw) {
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    if (raw is num) return raw.toDouble();
    return double.tryParse((raw ?? '').toString());
  }
}
