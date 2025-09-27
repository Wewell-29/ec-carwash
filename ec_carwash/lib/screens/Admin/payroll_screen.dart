import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  bool _isLoading = true;
  Map<String, double> _teamCommissions = {
    'Team A': 0.0,
    'Team B': 0.0,
  };
  Map<String, int> _teamBookingCounts = {
    'Team A': 0,
    'Team B': 0,
  };
  String _selectedPeriod = 'today'; // today, week, month, all

  @override
  void initState() {
    super.initState();
    _loadPayrollData();
  }

  Future<void> _loadPayrollData() async {
    setState(() => _isLoading = true);

    try {
      DateTime startDate = DateTime.now();
      DateTime endDate = DateTime.now();

      // Calculate date range based on selected period
      switch (_selectedPeriod) {
        case 'today':
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          endDate = startDate.add(const Duration(days: 1));
          break;
        case 'week':
          startDate = startDate.subtract(Duration(days: startDate.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          endDate = startDate.add(const Duration(days: 7));
          break;
        case 'month':
          startDate = DateTime(startDate.year, startDate.month, 1);
          endDate = DateTime(startDate.year, startDate.month + 1, 1);
          break;
        case 'all':
          startDate = DateTime(2020, 1, 1); // Far past date
          endDate = DateTime.now().add(const Duration(days: 1));
          break;
      }

      // Query all transactions (will filter by team and status in memory)
      final transactionsSnapshot = await FirebaseFirestore.instance
          .collection('Transactions')
          .get();

      // Query completed bookings only (will filter by team in memory)
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('Bookings')
          .where('status', isEqualTo: 'completed')
          .get();

      // Calculate commissions
      Map<String, double> commissions = {'Team A': 0.0, 'Team B': 0.0};
      Map<String, int> counts = {'Team A': 0, 'Team B': 0};

      // Process transactions
      for (final doc in transactionsSnapshot.docs) {
        final data = doc.data();
        final team = data['assignedTeam'] as String?;
        final commission = (data['teamCommission'] as num?)?.toDouble() ?? 0.0;

        // Skip if no team assigned
        if (team == null || !commissions.containsKey(team)) {
          continue;
        }

        // Filter by date if not 'all'
        if (_selectedPeriod != 'all') {
          final transactionAt = (data['transactionAt'] as Timestamp?)?.toDate();
          if (transactionAt == null ||
              transactionAt.isBefore(startDate) ||
              transactionAt.isAfter(endDate)) {
            continue;
          }
        }

        commissions[team] = commissions[team]! + commission;
        counts[team] = counts[team]! + 1;
      }

      // Process bookings (only completed ones)
      for (final doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final team = data['assignedTeam'] as String?;
        final commission = (data['teamCommission'] as num?)?.toDouble() ?? 0.0;

        // Skip if no team assigned
        if (team == null || !commissions.containsKey(team)) {
          continue;
        }

        // Filter by date if not 'all'
        if (_selectedPeriod != 'all') {
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          if (createdAt == null ||
              createdAt.isBefore(startDate) ||
              createdAt.isAfter(endDate)) {
            continue;
          }
        }

        commissions[team] = commissions[team]! + commission;
        counts[team] = counts[team]! + 1;
      }

      setState(() {
        _teamCommissions = commissions;
        _teamBookingCounts = counts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading payroll data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Team Payroll',
          style: TextStyle(
            color: Colors.yellow.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.yellow.shade700),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter chips
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        _buildFilterChip('Today', 'today'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Week', 'week'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Month', 'month'),
                        const SizedBox(width: 8),
                        _buildFilterChip('All Time', 'all'),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _loadPayrollData,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Commission',
                          '₱${(_teamCommissions['Team A']! + _teamCommissions['Team B']!).toStringAsFixed(2)}',
                          Colors.black,
                          Icons.account_balance_wallet,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Jobs',
                          '${_teamBookingCounts['Team A']! + _teamBookingCounts['Team B']!}',
                          Colors.black,
                          Icons.work,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Team Cards
                  _buildTeamCard(
                    'Team A',
                    _teamCommissions['Team A']!,
                    _teamBookingCounts['Team A']!,
                    Colors.black,
                  ),
                  const SizedBox(height: 16),
                  _buildTeamCard(
                    'Team B',
                    _teamCommissions['Team B']!,
                    _teamBookingCounts['Team B']!,
                    Colors.black,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(String teamName, double commission, int jobCount, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.group,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teamName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      'Commission for ${_selectedPeriod == 'today' ? 'today' : _selectedPeriod == 'week' ? 'this week' : _selectedPeriod == 'month' ? 'this month' : 'all time'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Commission',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₱${commission.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.grey.shade300,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jobs Completed',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$jobCount',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedPeriod = value);
        _loadPayrollData();
      },
      selectedColor: Colors.yellow.shade700,
      checkmarkColor: Colors.black,
    );
  }
}