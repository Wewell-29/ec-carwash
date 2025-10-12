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

      // Query completed bookings only
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('Bookings')
          .where('status', isEqualTo: 'completed')
          .get();

      // Calculate commissions
      Map<String, double> commissions = {'Team A': 0.0, 'Team B': 0.0};
      Map<String, int> counts = {'Team A': 0, 'Team B': 0};

      // Process completed bookings only (single source of truth)
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
    final totalCommission = _teamCommissions['Team A']! + _teamCommissions['Team B']!;
    final totalJobs = _teamBookingCounts['Team A']! + _teamBookingCounts['Team B']!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildFilters(totalCommission, totalJobs),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildTeamCard(
                        'Team A',
                        _teamCommissions['Team A']!,
                        _teamBookingCounts['Team A']!,
                      ),
                      const SizedBox(height: 12),
                      _buildTeamCard(
                        'Team B',
                        _teamCommissions['Team B']!,
                        _teamBookingCounts['Team B']!,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(double totalCommission, int totalJobs) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              // Total Commission Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade50,
                  border: Border.all(color: Colors.black87, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Colors.black87, size: 20),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₱${totalCommission.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$totalJobs jobs',
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _loadPayrollData,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  backgroundColor: Colors.yellow.shade50,
                  side: const BorderSide(color: Colors.black87, width: 1.5),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Date Filters
          Row(
            children: [
              _buildFilterChip('Today', 'today'),
              const SizedBox(width: 8),
              _buildFilterChip('Week', 'week'),
              const SizedBox(width: 8),
              _buildFilterChip('Month', 'month'),
              const SizedBox(width: 8),
              _buildFilterChip('All', 'all'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(String teamName, double commission, int jobCount) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.yellow.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.black87, width: 1.5),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black87, width: 1),
                  ),
                  child: CircleAvatar(
                    backgroundColor: Colors.yellow.shade700,
                    radius: 24,
                    child: const Icon(
                      Icons.group,
                      color: Colors.black87,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teamName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Commission for ${_selectedPeriod == 'today' ? 'today' : _selectedPeriod == 'week' ? 'this week' : _selectedPeriod == 'month' ? 'this month' : 'all time'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withValues(alpha: 0.6),
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
                          fontSize: 15,
                          color: Colors.black.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.yellow.shade700,
                          border: Border.all(color: Colors.black87, width: 1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '₱${commission.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jobs Completed',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.yellow.shade700,
                          border: Border.all(color: Colors.black87, width: 1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$jobCount',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
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
        setState(() => _selectedPeriod = value);
        _loadPayrollData();
      },
      selectedColor: Colors.yellow.shade700,
      backgroundColor: Colors.grey.shade200,
      side: BorderSide(
        color: isSelected ? Colors.black87 : Colors.transparent,
        width: 1.5,
      ),
    );
  }
}