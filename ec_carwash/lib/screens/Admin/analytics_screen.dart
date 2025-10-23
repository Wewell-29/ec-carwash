import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:ec_carwash/data_models/expense_data.dart';
import 'package:ec_carwash/utils/csv_importer.dart';
import 'package:ec_carwash/data_models/unified_transaction_data.dart' as txn_model;
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedFilter = 'today'; // today, weekly, monthly, yearly, custom
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;

  // Peak Operating Time Data (bookings per time unit - hour/day/month depending on filter)
  Map<dynamic, int> _peakTimeData = {};

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
        case 'custom':
          if (_startDate != null && _endDate != null) {
            startDate = _startDate!;
            endDate = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
          } else {
            startDate = DateTime(now.year, now.month, now.day);
          }
          break;
        default:
          startDate = DateTime(now.year, now.month, now.day);
      }

      // Load completed bookings (filter in memory to avoid index requirement)
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('Bookings')
          .where('status', isEqualTo: 'completed')
          .get();

      // Load completed transactions (includes CSV imports and POS transactions)
      final transactionsSnapshot = await FirebaseFirestore.instance
          .collection('Transactions')
          .where('status', isEqualTo: 'completed')
          .get();

      // Process data with date filtering
      Map<dynamic, int> peakTimeCount = {};
      Map<String, double> serviceRev = {};
      double totalRev = 0.0;
      int txnCount = 0;

      // Process bookings
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
        // Use totalAmount (unified field) with fallback to 'total' for legacy data
        final total = (data['totalAmount'] as num?)?.toDouble() ??
                      (data['total'] as num?)?.toDouble() ?? 0.0;
        final services = data['services'] as List?;

        totalRev += total;

        // Peak time analysis - varies by filter
        dynamic timeKey;
        switch (_selectedFilter) {
          case 'today':
            // Group by hour (0-23)
            timeKey = createdAt.hour;
            break;
          case 'weekly':
            // Group by day of week (1=Monday, 7=Sunday)
            timeKey = createdAt.weekday;
            break;
          case 'monthly':
            // Group by day of month (1-31)
            timeKey = createdAt.day;
            break;
          case 'yearly':
            // Group by month (1-12)
            timeKey = createdAt.month;
            break;
          case 'custom':
            // Determine based on date range span
            final daysDiff = endDate.difference(startDate).inDays;
            if (daysDiff <= 1) {
              timeKey = createdAt.hour; // Hours for single day
            } else if (daysDiff <= 31) {
              timeKey = createdAt.day; // Days for up to a month
            } else if (daysDiff <= 366) {
              timeKey = createdAt.month; // Months for up to a year
            } else {
              timeKey = createdAt.year; // Years for longer periods
            }
            break;
          default:
            timeKey = createdAt.hour;
        }

        peakTimeCount[timeKey] = (peakTimeCount[timeKey] ?? 0) + 1;

        // Top services analysis
        if (services != null) {
          for (final service in services) {
            final serviceName = service['serviceName'] ?? 'Unknown';
            final price = (service['price'] as num?)?.toDouble() ?? 0.0;
            serviceRev[serviceName] = (serviceRev[serviceName] ?? 0.0) + price;
          }
        }
      }

      // Process transactions (CSV imports, POS transactions)
      for (final doc in transactionsSnapshot.docs) {
        final data = doc.data();
        final transactionAt = (data['transactionAt'] as Timestamp?)?.toDate();

        // Filter by date range
        if (transactionAt == null ||
            transactionAt.isBefore(startDate) ||
            transactionAt.isAfter(endDate)) {
          continue;
        }

        txnCount++;
        final total = (data['total'] as num?)?.toDouble() ?? 0.0;
        final services = data['services'] as List?;

        totalRev += total;

        // Peak time analysis
        dynamic timeKey;
        switch (_selectedFilter) {
          case 'today':
            timeKey = transactionAt.hour;
            break;
          case 'weekly':
            timeKey = transactionAt.day;
            break;
          case 'monthly':
            timeKey = transactionAt.day;
            break;
          case 'yearly':
            timeKey = transactionAt.month;
            break;
          case 'custom':
            final daysDiff = endDate.difference(startDate).inDays;
            if (daysDiff <= 1) {
              timeKey = transactionAt.hour;
            } else if (daysDiff <= 31) {
              timeKey = transactionAt.day;
            } else if (daysDiff <= 366) {
              timeKey = transactionAt.month;
            } else {
              timeKey = transactionAt.year;
            }
            break;
          default:
            timeKey = transactionAt.hour;
        }

        peakTimeCount[timeKey] = (peakTimeCount[timeKey] ?? 0) + 1;

        // Top services analysis
        if (services != null) {
          for (final service in services) {
            final serviceName = service['serviceName'] ??
                               service['serviceCode'] ?? 'Unknown';
            final price = (service['price'] as num?)?.toDouble() ?? 0.0;
            final quantity = (service['quantity'] as num?)?.toInt() ?? 1;
            serviceRev[serviceName] = (serviceRev[serviceName] ?? 0.0) + (price * quantity);
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
          _peakTimeData = peakTimeCount;
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
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _showCustomRangeDialog,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              backgroundColor: _selectedFilter == 'custom' ? Colors.yellow.shade700 : Colors.yellow.shade50,
              side: BorderSide(color: Colors.black87, width: _selectedFilter == 'custom' ? 1.5 : 1),
            ),
            icon: const Icon(Icons.date_range, size: 18),
            label: Text(
              _selectedFilter == 'custom' && _startDate != null && _endDate != null
                  ? 'Custom Range'
                  : 'Custom',
              style: TextStyle(
                fontWeight: _selectedFilter == 'custom' ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const Spacer(),
          // Import CSV Button
          ElevatedButton.icon(
            onPressed: _showImportCSVDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.upload_file, size: 20),
            label: const Text(
              'Import CSV',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
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
    // Determine title and labels based on filter
    String chartTitle;
    String chartSubtitle;
    Map<int, int> completeData = {};

    switch (_selectedFilter) {
      case 'today':
        chartTitle = 'Peak Operating Hours';
        chartSubtitle = 'Busiest times of the day';
        // Hours from 8 AM to 6 PM
        for (int hour = 8; hour <= 18; hour++) {
          completeData[hour] = _peakTimeData[hour] ?? 0;
        }
        break;
      case 'weekly':
        chartTitle = 'Peak Operating Days';
        chartSubtitle = 'Busiest days of the week';
        // Days 1-7 (Mon-Sun)
        for (int day = 1; day <= 7; day++) {
          completeData[day] = _peakTimeData[day] ?? 0;
        }
        break;
      case 'monthly':
        chartTitle = 'Peak Operating Days';
        chartSubtitle = 'Busiest days of the month';
        // Days 1-31
        for (int day = 1; day <= 31; day++) {
          completeData[day] = _peakTimeData[day] ?? 0;
        }
        break;
      case 'yearly':
        chartTitle = 'Peak Operating Months';
        chartSubtitle = 'Busiest months of the year';
        // Months 1-12
        for (int month = 1; month <= 12; month++) {
          completeData[month] = _peakTimeData[month] ?? 0;
        }
        break;
      case 'custom':
        // Determine based on data keys
        if (_peakTimeData.isEmpty) {
          chartTitle = 'Peak Times';
          chartSubtitle = 'No data available';
        } else {
          final sampleKey = _peakTimeData.keys.first;
          if (sampleKey is int && sampleKey >= 0 && sampleKey <= 23) {
            chartTitle = 'Peak Operating Hours';
            chartSubtitle = 'Busiest times in selected period';
            for (int hour = 8; hour <= 18; hour++) {
              completeData[hour] = _peakTimeData[hour] ?? 0;
            }
          } else if (sampleKey is int && sampleKey >= 1 && sampleKey <= 31) {
            chartTitle = 'Peak Operating Days';
            chartSubtitle = 'Busiest days in selected period';
            for (int day = 1; day <= 31; day++) {
              completeData[day] = _peakTimeData[day] ?? 0;
            }
          } else {
            chartTitle = 'Peak Operating Months';
            chartSubtitle = 'Busiest months in selected period';
            for (int month = 1; month <= 12; month++) {
              completeData[month] = _peakTimeData[month] ?? 0;
            }
          }
        }
        break;
      default:
        chartTitle = 'Peak Operating Hours';
        chartSubtitle = 'Busiest times of the day';
        for (int hour = 8; hour <= 18; hour++) {
          completeData[hour] = _peakTimeData[hour] ?? 0;
        }
    }

    final maxBookings = completeData.values.isEmpty
        ? 1
        : completeData.values.reduce((a, b) => a > b ? a : b);

    // If no bookings, show empty state
    if (maxBookings == 0 || completeData.isEmpty) {
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
                  Text(
                    chartTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'No booking data available for the selected period',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
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
                Icon(Icons.access_time, color: Colors.black87, size: 20),
                const SizedBox(width: 8),
                Text(
                  chartTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              chartSubtitle,
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
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.black87,
                      tooltipRoundedRadius: 8,
                      tooltipPadding: const EdgeInsets.all(8),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        String label = _getTooltipLabel(group.x.toInt(), _selectedFilter);
                        return BarTooltipItem(
                          '$label\n${rod.toY.toInt()} bookings',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
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
                        getTitlesWidget: (value, meta) {
                          return _getBottomTitle(value.toInt(), _selectedFilter);
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        interval: maxBookings > 10 ? null : (maxBookings > 5 ? 2 : 1),
                        getTitlesWidget: (value, meta) {
                          if (value == 0 || value > maxBookings) return const SizedBox.shrink();
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
                  barGroups: completeData.entries.map((entry) {
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

  Widget _getBottomTitle(int value, String filter) {
    String label;
    switch (filter) {
      case 'today':
        // Hours (8 AM - 6 PM)
        final period = value >= 12 ? 'PM' : 'AM';
        final displayHour = value == 0 ? 12 : (value > 12 ? value - 12 : value);
        label = '$displayHour$period';
        break;
      case 'weekly':
        // Days of week
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        label = value >= 1 && value <= 7 ? days[value - 1] : '';
        break;
      case 'monthly':
        // Days of month (show key days to avoid crowding)
        if (value == 1 || value % 5 == 0) {
          label = value.toString();
        } else {
          label = '';
        }
        break;
      case 'yearly':
        // Months
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        label = value >= 1 && value <= 12 ? months[value - 1] : '';
        break;
      case 'custom':
        // Determine based on value range
        if (value >= 0 && value <= 23) {
          // Hours
          final period = value >= 12 ? 'PM' : 'AM';
          final displayHour = value == 0 ? 12 : (value > 12 ? value - 12 : value);
          label = '$displayHour$period';
        } else if (value >= 1 && value <= 31) {
          // Days
          label = value % 5 == 0 || value == 1 ? value.toString() : '';
        } else if (value >= 1 && value <= 12) {
          // Months
          const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          label = months[value - 1];
        } else {
          label = value.toString();
        }
        break;
      default:
        label = value.toString();
    }
    return Text(
      label,
      style: const TextStyle(fontSize: 10, color: Colors.black87),
    );
  }

  String _getTooltipLabel(int value, String filter) {
    switch (filter) {
      case 'today':
        // Hours (full format)
        final period = value >= 12 ? 'PM' : 'AM';
        final displayHour = value == 0 ? 12 : (value > 12 ? value - 12 : value);
        return '$displayHour:00 $period';
      case 'weekly':
        // Days of week (full name)
        const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        return value >= 1 && value <= 7 ? days[value - 1] : 'Day $value';
      case 'monthly':
        // Days of month (with ordinal)
        return 'Day $value';
      case 'yearly':
        // Months (full name)
        const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
        return value >= 1 && value <= 12 ? months[value - 1] : 'Month $value';
      case 'custom':
        // Determine based on value range
        if (value >= 0 && value <= 23) {
          final period = value >= 12 ? 'PM' : 'AM';
          final displayHour = value == 0 ? 12 : (value > 12 ? value - 12 : value);
          return '$displayHour:00 $period';
        } else if (value >= 1 && value <= 31) {
          return 'Day $value';
        } else if (value >= 1 && value <= 12) {
          const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
          return months[value - 1];
        } else {
          return 'Day $value';
        }
      default:
        return value.toString();
    }
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

  void _showCustomRangeDialog() {
    showDialog(
      context: context,
      builder: (context) => _CustomRangeDialog(
        startDate: _startDate,
        endDate: _endDate,
        onApply: (start, end) {
          setState(() {
            _startDate = start;
            _endDate = end;
            _selectedFilter = 'custom';
          });
          _loadAnalyticsData();
        },
      ),
    );
  }

  /// Show CSV Import Dialog
  Future<void> _showImportCSVDialog() async {
    try {
      // Pick CSV file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      final file = result.files.first;
      if (file.bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file')),
          );
        }
        return;
      }

      // Decode CSV content
      final csvContent = utf8.decode(file.bytes!);
      debugPrint('CSV content length: ${csvContent.length}');
      debugPrint('First 200 chars: ${csvContent.substring(0, csvContent.length > 200 ? 200 : csvContent.length)}');

      // Validate CSV format
      if (!CSVImporter.validateCSVFormat(csvContent)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid CSV format. Expected columns: Date, Time, Team, Service, Price'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Show confirmation dialog with preview
      if (mounted) {
        await _showImportConfirmationDialog(csvContent, file.name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show import confirmation dialog with preview
  Future<void> _showImportConfirmationDialog(
    String csvContent,
    String fileName,
  ) async {
    try {
      // Parse CSV to preview
      final transactions = CSVImporter.parseCSV(csvContent);

      if (transactions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid transactions found in CSV')),
          );
        }
        return;
      }

      // Show preview dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.upload_file, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Import CSV Transactions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      fileName,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 600,
            height: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Found ${transactions.length} transaction(s) to import',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Preview (first 5 rows):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        border: TableBorder.all(color: Colors.grey.shade300),
                        headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Team')),
                          DataColumn(label: Text('Plate')),
                          DataColumn(label: Text('Services')),
                          DataColumn(label: Text('Amount')),
                        ],
                        rows: transactions.take(5).map((txn) {
                          return DataRow(cells: [
                            DataCell(Text(
                              '${txn.transactionAt.month}/${txn.transactionAt.day}/${txn.transactionAt.year}',
                            )),
                            DataCell(Text(txn.assignedTeam ?? 'N/A')),
                            DataCell(Text(txn.vehiclePlateNumber)),
                            DataCell(Text(
                              txn.services.map((s) => s.serviceCode).join(', '),
                            )),
                            DataCell(Text('₱${txn.total.toStringAsFixed(2)}')),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check),
              label: const Text('Import All'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        await _performImport(transactions);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error parsing CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Perform the actual import
  Future<void> _performImport(List<txn_model.Transaction> transactions) async {
    if (transactions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No transactions to import'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text('Importing ${transactions.length} transactions...'),
          ],
        ),
      ),
    );

    try {
      debugPrint('Starting import of ${transactions.length} transactions');

      // Resolve service names from Firestore
      debugPrint('Resolving service names...');
      await CSVImporter.resolveServiceNames(transactions);

      // Import to Firestore
      debugPrint('Importing to Firestore...');
      final importedCount = await CSVImporter.importToFirestore(transactions);
      debugPrint('Import completed: $importedCount transactions');

      if (mounted) {
        Navigator.pop(context); // Close progress dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ Successfully imported $importedCount transaction(s)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Reload analytics data
        await _loadAnalyticsData();
      }
    } catch (e, stackTrace) {
      debugPrint('Import error: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        Navigator.pop(context); // Close progress dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }
}

// Custom Range Dialog Widget
class _CustomRangeDialog extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateTime start, DateTime end) onApply;

  const _CustomRangeDialog({
    this.startDate,
    this.endDate,
    required this.onApply,
  });

  @override
  State<_CustomRangeDialog> createState() => _CustomRangeDialogState();
}

class _CustomRangeDialogState extends State<_CustomRangeDialog> {
  int? _startMonth;
  int? _startYear;
  int? _endMonth;
  int? _endYear;

  @override
  void initState() {
    super.initState();
    if (widget.startDate != null) {
      _startMonth = widget.startDate!.month;
      _startYear = widget.startDate!.year;
    }
    if (widget.endDate != null) {
      _endMonth = widget.endDate!.month;
      _endYear = widget.endDate!.year;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Date Range', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Start Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      border: OutlineInputBorder(),
                    ),
                    value: _startMonth,
                    items: List.generate(12, (index) {
                      final month = index + 1;
                      return DropdownMenuItem(
                        value: month,
                        child: Text(DateTime(2000, month).toString().split(' ')[0].split('-')[1]),
                      );
                    }),
                    onChanged: (value) => setState(() => _startMonth = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                    ),
                    value: _startYear,
                    items: List.generate(5, (index) {
                      final year = DateTime.now().year - index;
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }),
                    onChanged: (value) => setState(() => _startYear = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('End Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      border: OutlineInputBorder(),
                    ),
                    value: _endMonth,
                    items: List.generate(12, (index) {
                      final month = index + 1;
                      return DropdownMenuItem(
                        value: month,
                        child: Text(DateTime(2000, month).toString().split(' ')[0].split('-')[1]),
                      );
                    }),
                    onChanged: (value) => setState(() => _endMonth = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                    ),
                    value: _endYear,
                    items: List.generate(5, (index) {
                      final year = DateTime.now().year - index;
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }),
                    onChanged: (value) => setState(() => _endYear = value),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_startMonth == null || _startYear == null || _endMonth == null || _endYear == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select both start and end dates')),
              );
              return;
            }

            final startDate = DateTime(_startYear!, _startMonth!, 1);
            final endDate = DateTime(_endYear!, _endMonth! + 1, 1).subtract(const Duration(seconds: 1));

            if (endDate.isBefore(startDate)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('End date must be after start date')),
              );
              return;
            }

            Navigator.pop(context);
            widget.onApply(startDate, endDate);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.yellow.shade700,
            foregroundColor: Colors.black87,
          ),
          child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
