import 'dart:async';

import 'package:flutter/material.dart';
import 'package:khaadim/services/api_client.dart';

class AIScreen extends StatefulWidget {
  const AIScreen({super.key});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> with TickerProviderStateMixin {
  final Map<String, Map<String, dynamic>> _cache = {};

  String? _selectedType;
  String? _hoveredType;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _suggestions = [];
  DateTime? _generatedAt;

  late final AnimationController _pulseController;
  late AnimationController _staggerController;

  static const Color _cardBg = Color(0xFF0D111C);
  static const Color _cardBorder = Color(0xFF1A2035);
  static const Color _mutedBlue = Color(0xFF64748B);
  static const Color _accent = Color(0xFF6366F1);

  final List<_InsightType> _types = const [
    _InsightType(type: 'revenue', icon: '📈', label: 'Revenue Insights'),
    _InsightType(type: 'menu', icon: '🍔', label: 'Menu Performance'),
    _InsightType(type: 'forecast', icon: '🔮', label: 'Demand Forecast'),
    _InsightType(type: 'retention', icon: '🔁', label: 'Retention Strategy'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _selectType(String type, {bool forceRegenerate = false}) async {
    if (_isLoading && _selectedType == type && !forceRegenerate) return;

    setState(() {
      _selectedType = type;
      _errorMessage = null;
      if (forceRegenerate) {
        _cache.remove(type);
      }
    });

    if (!forceRegenerate && _cache.containsKey(type)) {
      _applyResponse(_cache[type]!);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final data = await ApiClient.postJson(
        '/admin/ai-suggestions',
        body: {'type': type},
        auth: true,
      );

      if (!mounted) return;
      _cache[type] = data;
      _applyResponse(data);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _suggestions = [];
        _generatedAt = null;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _suggestions = [];
        _generatedAt = null;
        _errorMessage = 'AI service temporarily unavailable. Please try again.';
      });
    }
  }

  void _applyResponse(Map<String, dynamic> data) {
    final rawSuggestions = (data['suggestions'] as List<dynamic>? ?? []);
    final parsedSuggestions = rawSuggestions
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    DateTime? generatedAt;
    final generatedRaw = data['generated_at'];
    if (generatedRaw is String && generatedRaw.trim().isNotEmpty) {
      generatedAt = DateTime.tryParse(generatedRaw)?.toLocal();
    }

    final cardCount = parsedSuggestions.length;
    final durationMs = (280 + (cardCount * 80)).clamp(280, 1200);
    _staggerController.dispose();
    _staggerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );

    setState(() {
      _isLoading = false;
      _errorMessage = null;
      _suggestions = parsedSuggestions;
      _generatedAt = generatedAt;
    });

    _staggerController.forward(from: 0);
  }

  String _formatGeneratedTime(DateTime dt) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(dt),
      alwaysUse24HourFormat: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return Container(
          color: const Color(0xFF07090F),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 14 : 24,
                    vertical: isMobile ? 14 : 20,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderCard(isMobile),
                          const SizedBox(height: 14),
                          _buildTypeSelector(isMobile),
                          const SizedBox(height: 16),
                          _buildResultsArea(isMobile),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: _cardBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'AI Business Insights',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Select a category to generate AI-powered recommendations',
                  style: TextStyle(
                    color: _mutedBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF13183A),
              border: Border.all(color: const Color(0xFF2A3558)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF818CF8)),
                SizedBox(width: 5),
                Text(
                  'AI',
                  style: TextStyle(
                    color: Color(0xFF818CF8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(bool isMobile) {
    if (isMobile) {
      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: _types.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.45,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemBuilder: (context, index) {
          return _buildTypeCard(_types[index], compact: true);
        },
      );
    }

    return Row(
      children: _types
          .map(
            (t) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: t == _types.last ? 0 : 10),
                child: _buildTypeCard(t),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTypeCard(_InsightType type, {bool compact = false}) {
    final isActive = _selectedType == type.type;
    final isHovered = _hoveredType == type.type;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final loadingPulse = (_isLoading && isActive) ? (1 + (_pulseController.value * 0.025)) : 1.0;
        return Transform.scale(
          scale: loadingPulse,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              mouseCursor: SystemMouseCursors.click,
              hoverColor: Colors.transparent,
              onHover: (hovering) {
                if (!mounted) return;
                if (hovering && _hoveredType != type.type) {
                  setState(() => _hoveredType = type.type);
                } else if (!hovering && _hoveredType == type.type) {
                  setState(() => _hoveredType = null);
                }
              },
              onTap: () => _selectType(type.type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.symmetric(
                  vertical: compact ? 12 : 16,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF13183A) : _cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive
                        ? _accent
                        : (isHovered ? const Color(0xFF2A3558) : _cardBorder),
                    width: isActive ? 2 : 1,
                  ),
                  boxShadow: (_isLoading && isActive)
                      ? [
                          BoxShadow(
                            color: _accent.withOpacity(0.15 + (_pulseController.value * 0.12)),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : const [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(type.icon, style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 8),
                    Text(
                      type.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isActive ? const Color(0xFFE2E8F0) : const Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultsArea(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: _cardBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 860),
          child: _buildResultsContent(),
        ),
      ),
    );
  }

  Widget _buildResultsContent() {
    if (_selectedType == null) {
      return const SizedBox(
        height: 210,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insights_outlined, color: Color(0xFF3D4A6B), size: 24),
              SizedBox(height: 8),
              Text(
                'Select a category above to generate insights',
                style: TextStyle(
                  color: Color(0xFF3D4A6B),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const SizedBox(
        height: 210,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: Color(0xFF6366F1),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Analysing data with AI...',
                style: TextStyle(
                  color: Color(0xFF5A6A8A),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'AI service temporarily unavailable. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF2A3558)),
                  foregroundColor: const Color(0xFF94A3B8),
                ),
                onPressed: _selectedType == null ? null : () => _selectType(_selectedType!, forceRegenerate: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'No suggestions available right now.',
            style: TextStyle(color: Color(0xFF5A6A8A), fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._suggestions.asMap().entries.map((entry) {
          final index = entry.key;
          final suggestion = entry.value;

          final intervalStart = (_suggestions.length <= 1)
              ? 0.0
              : (index * 0.08).clamp(0.0, 0.9);
          final interval = Interval(intervalStart, 1.0, curve: Curves.easeOutCubic);
          final animation = CurvedAnimation(parent: _staggerController, curve: interval);

          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final fade = animation.value;
              final dy = 14 * (1 - fade);

              return Opacity(
                opacity: fade,
                child: Transform.translate(
                  offset: Offset(0, dy),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildSuggestionCard(suggestion, index + 1),
                  ),
                ),
              );
            },
          );
        }),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                _generatedAt == null
                  ? 'Generated just now · AI'
                  : 'Generated at ${_formatGeneratedTime(_generatedAt!)} · AI',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF2A3558),
                  fontSize: 11,
                ),
              ),
            ),
            TextButton(
              onPressed: _selectedType == null ? null : () => _selectType(_selectedType!, forceRegenerate: true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF5A6A8A),
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              child: const Text('↺ Regenerate'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuggestionCard(Map<String, dynamic> suggestion, int fallbackIndex) {
    final index = _intValue(suggestion['index']) ?? fallbackIndex;
    final heading = (suggestion['heading'] ?? '').toString().trim();
    final text = (suggestion['text'] ?? '').toString().trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF13183A),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: Color(0xFF818CF8),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(left: 12),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Color(0xFF6366F1), width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    heading.isEmpty ? 'Insight' : heading,
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                      height: 1.65,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int? _intValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

class _InsightType {
  final String type;
  final String icon;
  final String label;

  const _InsightType({
    required this.type,
    required this.icon,
    required this.label,
  });
}
