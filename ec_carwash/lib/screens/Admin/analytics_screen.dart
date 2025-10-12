import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:ec_carwash/data_models/expense_data.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedFilter = 'today'; // today, weekly, monthly, yearly
  bool _isLoading = true;

  // Peak Operating Time Data (bookings per hour)
  Map<int, int> _hourlyBookings = {};

  // Top Services Data
  Map<String, double> _serviceRevenue = {};

  // Expenses Pattern Data
  Map<String, double> _expensesByCategory = {};

  // Sales Report Data
  double _totalRevenue = 0.0;
  int _totalTransactions = 0;
  double _totalExpenses = 0.0;
  double _profitMargin = 0.0;
  bool _showSalesReport = false;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // Calculate date range based on filter
      switch (_selectedFilter) {
        case 'today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'weekly':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          endDate = startDate.add(const Duration(days: 7));
          break;
        case 'monthly':
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1));
          break;
        case 'yearly':
          startDate = DateTime(now.year, 1, 1);
          endDate = DateTime(now.year, 12, 31, 23, 59, 59);
          break;
        default:
          startDate = DateTime(now.year, now.month, now.day);
      }

      // Load completed bookings (filter in memory to avoid index requirement)
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('Bookings')
          .where('status', isEqualTo: 'completed')
          .get();

      // Process data with date filtering
      Map<int, int> hourlyBookingCount = {};
      Map<String, double> serviceRev = {};
      double totalRev = 0.0;
      int txnCount = 0;

      for (final doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        // Filter by date range
        if (createdAt == null ||
            createdAt.isBefore(startDate) ||
            createdAt.isAfter(endDate)) {
          continue;
        }

        txnCount++;
        final total = (data['total'] as num?)?.toDouble() ?? 0.0;
        final services = data['services'] as List?;

        totalRev += total;

        // Peak operating time analysis (count bookings per hour)
        final hour = createdAt.hour;
        hourlyBookingCount[hour] = (hourlyBookingCount[hour] ?? 0) + 1;

        // Top services analysis
        if (services != null) {
          for (final service in services) {
            final serviceName = service['serviceName'] ?? 'Unknown';
            final price = (service['price'] as num?)?.toDouble() ?? 0.0;
            serviceRev[serviceName] = (serviceRev[serviceName] ?? 0.0) + price;
          }
        }
      }

      // Load expenses for the period
      final expenses = await ExpenseManager.getExpenses(
        startDate: startDate,
        endDate: endDate,
      );

      Map<String, double> expensesByCat = {};
      double totalExp = 0.0;

      for (final expense in expenses) {
        totalExp += expense.amount;
        expensesByCat[expense.category] = (expensesByCat[expense.category] ?? 0.0) + expense.amount;
      }

      // Calculate profit margin
      final profit = totalRev - totalExp;
      final profitMargin = totalRev > 0 ? (profit / totalRev) * 100 : 0.0;

      if (mounted) {
        setState(() {
          _hourlyBookings = hourlyBookingCount;
          _serviceRevenue = serviceRev;
          _expensesByCategory = expensesByCat;
          _totalRevenue = totalRev;
          _totalTransactions = txnCount;
          _totalExpenses = totalExp;
          _profitMargin = profitMargin;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading analytics: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    try {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // All charts stacked vertically
            _buildPeakOperatingTimeChart(),
            const SizedBox(height: 20),
            _buildTopServicesChart(),
            const SizedBox(height: 20),
            _buildExpensesPatternChart(),
            const SizedBox(height: 20),
            // Sales Report at bottom (expandable button)
            _buildSalesReportButton(),
          ],
        ),
      );
    } catch (e) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading analytics',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildFilterChip('Today', 'today'),
          const SizedBox(width: 8),
          _buildFilterChip('Weekly', 'weekly'),
          const SizedBox(width: 8),
          _buildFilterChip('Monthly', 'monthly'),
          const SizedBox(width: 8),
          _buildFilterChip('Yearly', 'yearly'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black87 : Colors.black.withValues(alpha: 0.7),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedFilter = value);
        _loadAnalyticsData();
      },
      selectedColor: Colors.yellow.shade700,
      backgroundColor: Colors.grey.shade200,
      side: BorderSide(
        color: isSelected ? Colors.black87 : Colors.transparent,
        width: 1.5,
      ),
    );
  }

  Widget _buildSalesReportButton() {
    return Card(
      color: Colors.yellow.shade50,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black87, width: 1.5),
      ),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.yellow.shade700,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black87, width: 1),
          ),
          child: const Icon(Icons.analytics, color: Colors.black87, size: 20),
        ),
        title: const Text(
          'Sales Report',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          'Click to view detailed report',
          style: TextStyle(
            fontSize: 13,
            color: Colors.black.withValues(alpha: 0.6),
          ),
        ),
        initiallyExpanded: _showSalesReport,
        onExpansionChanged: (expanded) {
          setState(() => _showSalesReport = expanded);
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: _buildSalesReportContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesReportContent() {
    final profit = _totalRevenue - _totalExpenses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildSalesMetric('Total Revenue', '₱${_totalRevenue.toStringAsFixed(2)}')),
            const SizedBox(width: 16),
            Expanded(child: _buildSalesMetric('Transactions', '$_totalTransactions')),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildSalesMetric('Total Expenses', '₱${_totalExpenses.toStringAsFixed(2)}')),
            const SizedBox(width: 16),
            Expanded(child: _buildSalesMetric('Profit', '₱${profit.toStringAsFixed(2)}')),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.yellow.shade700,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black87, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Profit Margin',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                '${_profitMargin.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        if (_serviceRevenue.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Top Revenue Packages',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ..._getTopServices(3).map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '₱${entry.value.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildSalesMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black87, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  List<MapEntry<String, double>> _getTopServices(int limit) {
    final entries = _serviceRevenue.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }

  Widget _buildPeakOperatingTimeChart() {
    // Create complete hour range from 8 AM to 6 PM with 0 bookings as default
    final Map<int, int> completeHours = {};
    for (int hour = 8; hour <= 18; hour++) {
      completeHours[hour] = _hourlyBookings[hour] ?? 0;
    }

    final maxBookings = completeHours.values.reduce((a, b) => a > b ? a : b);

    return Card(
      color: Colors.yellow.shade50,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black87, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.black87, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Peak Operating Hours',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Busiest times of the day',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (maxBookings * 1.2).toDouble(),
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final hour = value.toInt();
                          final period = hour >= 12 ? 'PM' : 'AM';
                          final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
                          return Text(
                            '$displayHour$period',
                            style: const TextStyle(fontSize: 10, color: Colors.black87),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}',
                            style: const TextStyle(fontSize: 10, color: Colors.black87),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (maxBookings * 1.2) / 5,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: completeHours.entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          color: Colors.yellow.shade700,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          borderSide: const BorderSide(color: Colors.black87, width: 1),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopServicesChart() {
    if (_serviceRevenue.isEmpty) {
      return _buildEmptyChart('Top Service Packages', 'No data available');
    }

    final topServices = _getTopServices(5);
    final total = topServices.fold(0.0, (acc, entry) => acc + entry.value);

    if (total == 0 || topServices.isEmpty) {
      return _buildEmptyChart('Top Service Packages', 'No data available');
    }

    return Card(
      color: Colors.yellow.shade50,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black87, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.black87, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Top Service Packages',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sections: topServices.asMap().entries.where((entry) => entry.value.value > 0).map((entry) {
                          final index = entry.key;
                          final data = entry.value;
                          final percentage = (data.value / total) * 100;
                          final colors = [
                            Colors.yellow.shade700,
                            Colors.yellow.shade600,
                            Colors.yellow.shade500,
                            Colors.yellow.shade400,
                            Colors.yellow.shade300,
                          ];
                          return PieChartSectionData(
                            color: colors[index % colors.length],
                            value: data.value,
                            title: '${percentage.toStringAsFixed(0)}%',
                            radius: 100,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            borderSide: const BorderSide(color: Colors.black87, width: 1),
                          );
                        }).toList(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: topServices.asMap().entries.map((entry) {
                        final index = entry.key;
                        final data = entry.value;
                        final colors = [
                          Colors.yellow.shade700,
                          Colors.yellow.shade600,
                          Colors.yellow.shade500,
                          Colors.yellow.shade400,
                          Colors.yellow.shade300,
                        ];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: colors[index % colors.length],
                                  border: Border.all(color: Colors.black87, width: 1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data.key,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '₱${data.value.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesPatternChart() {
    if (_expensesByCategory.isEmpty) {
      return _buildEmptyChart('Expenses Pattern', 'No expenses data available');
    }

    final total = _expensesByCategory.values.fold(0.0, (acc, value) => acc + value);

    if (total == 0) {
      return _buildEmptyChart('Expenses Pattern', 'No expenses data available');
    }

    return Card(
      color: Colors.yellow.shade50,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black87, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.money_off, color: Colors.black87, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Expenses Pattern',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Total Expenses: ₱${total.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            ..._expensesByCategory.entries.map((entry) {
              final percentage = (entry.value / total) * 100;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          '₱${entry.value.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        minHeight: 12,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow.shade700),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChart(String title, String message) {
    return Card(
      color: Colors.yellow.shade50,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black87, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            Icon(Icons.bar_chart, size: 48, color: Colors.black.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
