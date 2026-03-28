import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:khaadim/services/api_client.dart';

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  bool _isLoading = true;

  // Filters
  int _selectedPeriod = 30; // 7, 30, 90
  String _selectedCategory = 'all';

  final List<Map<String, String>> _categories = [
    {'value': 'all', 'label': 'All Categories'},
    {'value': 'main', 'label': 'Main'},
    {'value': 'side', 'label': 'Sides'},
    {'value': 'drink', 'label': 'Drink'},
    {'value': 'starter', 'label': 'Starters'},
    {'value': 'bread', 'label': 'Bread'},
  ];

  // Data
  int _totalOrders = 0;
  double _totalRevenue = 0.0;
  double _totalProfit = 0.0;
  double _aov = 0.0;
  List<Map<String, dynamic>> _dailyData = [];

  String _formatAmountNoDecimals(double value) => value.round().toString();

  @override
  void initState() {
    super.initState();
    _fetchRevenueData();
  }

  Future<void> _fetchRevenueData() async {
    setState(() => _isLoading = true);
    try {
      final endpoint =
          '/admin/revenue?period=$_selectedPeriod&category=$_selectedCategory';
      final data = await ApiClient.getJson(endpoint, auth: true);

      if (mounted) {
        setState(() {
          _totalOrders = data['total_orders'] ?? 0;
          _totalRevenue = (data['total_revenue'] ?? 0.0).toDouble();
          _totalProfit = (data['total_profit'] ?? 0.0).toDouble();
          _aov = (data['aov'] ?? 0.0).toDouble();

          final rawDaily = data['daily_data'] as List<dynamic>? ?? [];
          _dailyData = rawDaily.map((e) => e as Map<String, dynamic>).toList();

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load revenue data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 1100;

        return Column(
          children: [
            _buildFilterBar(isDesktop),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildKpiSection(isDesktop),
                          const SizedBox(height: 24),
                          _buildChartSection(isDesktop),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar(bool isDesktop) {
    return Container(
      color: const Color(0xFF0D111C),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: isDesktop
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [_buildPeriodToggle(), _buildCategoryDropdown()],
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPeriodToggle(),
                  const SizedBox(width: 16),
                  _buildCategoryDropdown(),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13183A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1A2035)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [7, 30, 90].map((days) {
          final isSelected = _selectedPeriod == days;
          return InkWell(
            hoverColor: const Color(0xFF6366F1).withOpacity(0.10),
            splashColor: const Color(0xFF6366F1).withOpacity(0.18),
            onTap: () {
              if (!isSelected) {
                setState(() => _selectedPeriod = days);
                _fetchRevenueData();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6366F1).withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${days}D',
                style: TextStyle(
                  color: isSelected ? const Color(0xFF818CF8) : Colors.white70,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF13183A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1A2035)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          dropdownColor: const Color(0xFF13183A),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          items: _categories.map((cat) {
            return DropdownMenuItem(
              value: cat['value'],
              child: Text(cat['label'] ?? ''),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null && val != _selectedCategory) {
              setState(() => _selectedCategory = val);
              _fetchRevenueData();
            }
          },
        ),
      ),
    );
  }

  Widget _buildKpiSection(bool isDesktop) {
    if (isDesktop) {
      return Row(
        children: [
          Expanded(
            child: _buildKpiCard(
              'Total Revenue',
              'Rs ${_formatAmountNoDecimals(_totalRevenue)}',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildKpiCard(
              'Total Profit (Est)',
              'Rs ${_formatAmountNoDecimals(_totalProfit)}',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: _buildKpiCard('Total Orders', '$_totalOrders')),
          const SizedBox(width: 16),
          Expanded(
            child: _buildKpiCard(
              'Avg Order Value',
              'Rs ${_formatAmountNoDecimals(_aov)}',
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  'Total Revenue',
                  'Rs ${_formatAmountNoDecimals(_totalRevenue)}',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKpiCard(
                  'Total Profit',
                  'Rs ${_formatAmountNoDecimals(_totalProfit)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildKpiCard('Total Orders', '$_totalOrders')),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKpiCard(
                  'Avg Order Value',
                  'Rs ${_formatAmountNoDecimals(_aov)}',
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildKpiCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D111C),
        border: Border.all(color: const Color(0xFF1A2035), width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D111C),
        border: Border.all(color: const Color(0xFF1A2035), width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue Over Time',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: isDesktop ? 400 : 300,
            child: _dailyData.isEmpty
                ? const Center(
                    child: Text(
                      'No data for this period',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _getMaxY(),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => const Color(0xFF1E293B),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              'Rs ${rod.toY.toStringAsFixed(0)}',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              if (value < 0 || value >= _dailyData.length) {
                                return const SizedBox.shrink();
                              }
                              final skipRate = _dailyData.length > 30
                                  ? 7
                                  : (_dailyData.length > 14 ? 3 : 1);
                              if (value.toInt() % skipRate != 0) {
                                return const SizedBox.shrink();
                              }

                              final dateStr = _dailyData[value.toInt()]['date'];
                              final parts = dateStr.split('-');
                              final label = parts.length == 3
                                  ? '${parts[2]}/${parts[1]}'
                                  : dateStr;

                              return SideTitleWidget(
                                meta: meta,
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 50,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  _formatYAxisLabel(value),
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: const Border(
                          bottom: BorderSide(
                            color: Color(0xFF1A2035),
                            width: 1,
                          ),
                          left: BorderSide(color: Color(0xFF1A2035), width: 1),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: const Color(0xFF1A2035),
                          strokeWidth: 1,
                        ),
                      ),
                      barGroups: _dailyData
                          .asMap()
                          .entries
                          .map<BarChartGroupData>((entry) {
                            final index = entry.key;
                            final data = entry.value;
                            final rev = (data['revenue'] ?? 0.0) as double;
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: rev,
                                  color: const Color(
                                    0xFF6366F1,
                                  ).withOpacity(0.5),
                                  width: isDesktop ? 16 : 8,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                  backDrawRodData: BackgroundBarChartRodData(
                                    show: true,
                                    toY: _getMaxY(),
                                    color: Colors.transparent,
                                  ),
                                ),
                              ],
                              showingTooltipIndicators: [],
                            );
                          })
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  double _getMaxY() {
    if (_dailyData.isEmpty) return 100.0;
    double maxVal = 0;
    for (var d in _dailyData) {
      final rev = (d['revenue'] ?? 0.0) as double;
      if (rev > maxVal) maxVal = rev;
    }
    if (maxVal == 0) return 100.0;
    return maxVal * 1.2;
  }

  String _formatYAxisLabel(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toStringAsFixed(0);
  }
}
