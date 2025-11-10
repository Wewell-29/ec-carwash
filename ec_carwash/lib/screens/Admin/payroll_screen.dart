import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ec_carwash/data_models/expense_data.dart';
import 'package:ec_carwash/utils/reset_commissions.dart';
import 'package:ec_carwash/utils/delete_all_data.dart';

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
  Map<String, bool> _teamDisbursementStatus = {
    'Team A': false,
    'Team B': false,
  };
  Map<String, DateTime?> _teamDisbursementDate = {
    'Team A': null,
    'Team B': null,
  };

  @override
  void initState() {
    super.initState();
    _loadPayrollData();
  }

  Future<void> _disburseSalary(String teamName, double commission) async {
    try {
      // Initialize with today
      DateTime disbursementStartDate = DateTime.now();
      DateTime disbursementEndDate = DateTime.now();
      DateTime disbursementDate = DateTime.now();
      String selectedPeriodType = 'single'; // 'custom' or 'single'
      double periodAmount = 0.0;
      int periodJobCount = 0;
      bool isCalculating = false;
      bool hasCalculatedInitially = false;

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            String formatDisbursementPeriod() {
              if (selectedPeriodType == 'single') {
                return DateFormat('MMMM dd, yyyy').format(disbursementStartDate);
              } else {
                if (disbursementStartDate.year == disbursementEndDate.year &&
                    disbursementStartDate.month == disbursementEndDate.month &&
                    disbursementStartDate.day == disbursementEndDate.day) {
                  return DateFormat('MMMM dd, yyyy').format(disbursementStartDate);
                }
                return '${DateFormat('MMM dd, yyyy').format(disbursementStartDate)} - ${DateFormat('MMM dd, yyyy').format(disbursementEndDate)}';
              }
            }

            // Function to calculate amount for selected period
            Future<void> calculatePeriodAmount() async {
              setDialogState(() => isCalculating = true);

              try {
                final bookingsSnapshot = await FirebaseFirestore.instance
                    .collection('Bookings')
                    .where('status', isEqualTo: 'completed')
                    .where('assignedTeam', isEqualTo: teamName)
                    .get();

                final bookingsInPeriod = bookingsSnapshot.docs.where((doc) {
                  final data = doc.data();
                  final source = data['source'] as String? ?? '';

                  if (source == 'import') return false;

                  final completedAt = (data['completedAt'] as Timestamp?)?.toDate() ??
                                     (data['updatedAt'] as Timestamp?)?.toDate() ??
                                     (data['createdAt'] as Timestamp?)?.toDate();
                  final alreadyPaid = data['salaryDisbursed'] as bool? ?? false;

                  if (completedAt == null || alreadyPaid) return false;

                  final completedDate = DateTime(completedAt.year, completedAt.month, completedAt.day);
                  final periodStart = DateTime(disbursementStartDate.year, disbursementStartDate.month, disbursementStartDate.day);
                  final periodEnd = DateTime(disbursementEndDate.year, disbursementEndDate.month, disbursementEndDate.day, 23, 59, 59);

                  return (completedDate.isAtSameMomentAs(periodStart) || completedDate.isAfter(periodStart)) &&
                         (completedDate.isAtSameMomentAs(periodEnd) || completedDate.isBefore(periodEnd));
                }).toList();

                double amount = 0.0;
                for (final doc in bookingsInPeriod) {
                  final commissionValue = (doc.data()['teamCommission'] as num?)?.toDouble() ?? 0.0;
                  amount += commissionValue;
                }

                setDialogState(() {
                  periodAmount = amount;
                  periodJobCount = bookingsInPeriod.length;
                  isCalculating = false;
                });
              } catch (e) {
                setDialogState(() {
                  periodAmount = 0.0;
                  periodJobCount = 0;
                  isCalculating = false;
                });
              }
            }

            // Trigger initial calculation only once
            if (!hasCalculatedInitially) {
              hasCalculatedInitially = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                calculatePeriodAmount();
              });
            }

            return AlertDialog(
              title: const Text('Disburse Salary', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade50,
                        border: Border.all(color: Colors.black87),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Team: $teamName', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          if (isCalculating)
                            const Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('Calculating...', style: TextStyle(fontSize: 14)),
                              ],
                            )
                          else if (hasCalculatedInitially && periodAmount > 0)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Amount for Period: ₱${periodAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                                Text(
                                  '$periodJobCount job(s)',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                              ],
                            )
                          else if (hasCalculatedInitially && periodAmount == 0)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'No unpaid jobs in this period',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.orange),
                                ),
                                Text(
                                  'Total pending: ₱${commission.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            )
                          else
                            Text(
                              'Total Pending: ₱${commission.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Period Type Selection
                    const Text('Select Disbursement Period:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Single Day'),
                            selected: selectedPeriodType == 'single',
                            onSelected: (selected) {
                              if (selected) {
                                setDialogState(() {
                                  selectedPeriodType = 'single';
                                  disbursementEndDate = disbursementStartDate;
                                });
                              }
                            },
                            selectedColor: Colors.yellow.shade700,
                            backgroundColor: Colors.grey.shade200,
                            labelStyle: TextStyle(
                              color: selectedPeriodType == 'single' ? Colors.black87 : Colors.black54,
                              fontWeight: selectedPeriodType == 'single' ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Date Range'),
                            selected: selectedPeriodType == 'custom',
                            onSelected: (selected) {
                              if (selected) {
                                setDialogState(() => selectedPeriodType = 'custom');
                              }
                            },
                            selectedColor: Colors.yellow.shade700,
                            backgroundColor: Colors.grey.shade200,
                            labelStyle: TextStyle(
                              color: selectedPeriodType == 'custom' ? Colors.black87 : Colors.black54,
                              fontWeight: selectedPeriodType == 'custom' ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Period Selection
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.date_range, color: Colors.yellow.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  formatDisbursementPeriod(),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              if (selectedPeriodType == 'single') {
                                // Single day picker
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: disbursementStartDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                  builder: (context, child) {
                                    return Theme(
                                      data: ThemeData.light().copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: Colors.yellow.shade700,
                                          onPrimary: Colors.black87,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    disbursementStartDate = picked;
                                    disbursementEndDate = picked;
                                  });
                                  calculatePeriodAmount();
                                }
                              } else {
                                // Date range picker
                                final picked = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                  initialDateRange: DateTimeRange(
                                    start: disbursementStartDate,
                                    end: disbursementEndDate,
                                  ),
                                  builder: (context, child) {
                                    return Theme(
                                      data: ThemeData.light().copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: Colors.yellow.shade700,
                                          onPrimary: Colors.black87,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    disbursementStartDate = picked.start;
                                    disbursementEndDate = DateTime(
                                      picked.end.year,
                                      picked.end.month,
                                      picked.end.day,
                                      23, 59, 59,
                                    );
                                  });
                                  calculatePeriodAmount();
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.yellow.shade700,
                              foregroundColor: Colors.black87,
                              minimumSize: const Size(double.infinity, 36),
                            ),
                            icon: const Icon(Icons.edit_calendar, size: 18),
                            label: Text(
                              selectedPeriodType == 'single' ? 'Pick Day' : 'Pick Range',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Disbursement Date
                    const Text('Disbursement Date:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.yellow.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  DateFormat('MMMM dd, yyyy').format(disbursementDate),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: disbursementDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                builder: (context, child) {
                                  return Theme(
                                    data: ThemeData.light().copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: Colors.yellow.shade700,
                                        onPrimary: Colors.black87,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setDialogState(() => disbursementDate = picked);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.yellow.shade700,
                              foregroundColor: Colors.black87,
                              minimumSize: const Size(double.infinity, 36),
                            ),
                            icon: const Icon(Icons.edit_calendar, size: 18),
                            label: const Text('Change Date', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
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
                  onPressed: (hasCalculatedInitially && periodAmount == 0)
                    ? null
                    : () => Navigator.pop(context, {
                        'confirmed': true,
                        'disbursementStartDate': disbursementStartDate,
                        'disbursementEndDate': disbursementEndDate,
                        'disbursementDate': disbursementDate,
                      }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (hasCalculatedInitially && periodAmount == 0)
                        ? Colors.grey.shade300
                        : Colors.yellow.shade700,
                    foregroundColor: Colors.black87,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                  ),
                  child: const Text('Confirm Disbursement', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        ),
      );

      if (result == null || result['confirmed'] != true) return;

      final selectedDisbursementStartDate = result['disbursementStartDate'] as DateTime;
      final selectedDisbursementEndDate = result['disbursementEndDate'] as DateTime;
      final selectedDisbursementDate = result['disbursementDate'] as DateTime;

      // Create period ID based on selected disbursement period
      final periodId = '${selectedDisbursementStartDate.year}${selectedDisbursementStartDate.month.toString().padLeft(2, '0')}${selectedDisbursementStartDate.day.toString().padLeft(2, '0')}_${selectedDisbursementEndDate.year}${selectedDisbursementEndDate.month.toString().padLeft(2, '0')}${selectedDisbursementEndDate.day.toString().padLeft(2, '0')}';
      final docId = '${periodId}_$teamName';

      // Check if already disbursed for this specific period
      final existingDoc = await FirebaseFirestore.instance
          .collection('PayrollDisbursements')
          .doc(docId)
          .get();

      if (existingDoc.exists && existingDoc.data()?['isDisbursed'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Salary for this period has already been disbursed to $teamName'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Get all completed bookings for this team in the period
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('Bookings')
          .where('status', isEqualTo: 'completed')
          .where('assignedTeam', isEqualTo: teamName)
          .get();

      // Filter bookings within the period and not yet disbursed
      final bookingsInPeriod = bookingsSnapshot.docs.where((doc) {
        final data = doc.data();
        final source = data['source'] as String? ?? '';

        // Skip CSV imported bookings
        if (source == 'import') return false;

        // Use completedAt if available, fall back to updatedAt, then createdAt
        final completedAt = (data['completedAt'] as Timestamp?)?.toDate() ??
                           (data['updatedAt'] as Timestamp?)?.toDate() ??
                           (data['createdAt'] as Timestamp?)?.toDate();
        final alreadyPaid = data['salaryDisbursed'] as bool? ?? false;

        if (completedAt == null || alreadyPaid) return false;

        // Normalize dates to start/end of day for proper comparison
        final completedDate = DateTime(completedAt.year, completedAt.month, completedAt.day);
        final periodStart = DateTime(selectedDisbursementStartDate.year, selectedDisbursementStartDate.month, selectedDisbursementStartDate.day);
        final periodEnd = DateTime(selectedDisbursementEndDate.year, selectedDisbursementEndDate.month, selectedDisbursementEndDate.day, 23, 59, 59);

        return (completedDate.isAtSameMomentAs(periodStart) || completedDate.isAfter(periodStart)) &&
               (completedDate.isAtSameMomentAs(periodEnd) || completedDate.isBefore(periodEnd));
      }).toList();

      if (bookingsInPeriod.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No unpaid bookings found for $teamName in this period'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Calculate actual amount for this period
      double actualAmount = 0.0;
      for (final doc in bookingsInPeriod) {
        final commission = (doc.data()['teamCommission'] as num?)?.toDouble() ?? 0.0;
        actualAmount += commission;
      }

      // Save disbursement record
      await FirebaseFirestore.instance
          .collection('PayrollDisbursements')
          .doc(docId)
          .set({
        'teamName': teamName,
        'amount': actualAmount,
        'bookingCount': bookingsInPeriod.length,
        'periodStartDate': Timestamp.fromDate(selectedDisbursementStartDate),
        'periodEndDate': Timestamp.fromDate(selectedDisbursementEndDate),
        'disbursementDate': Timestamp.fromDate(selectedDisbursementDate),
        'isDisbursed': true,
        'disbursedAt': FieldValue.serverTimestamp(),
        'disbursedBy': 'Admin',
      });

      // Mark all bookings in this period as paid
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in bookingsInPeriod) {
        batch.update(doc.reference, {
          'salaryDisbursed': true,
          'salaryDisbursedDate': Timestamp.fromDate(selectedDisbursementDate),
          'salaryDisbursementId': docId,
        });
      }
      await batch.commit();

      // Record as expense under Utilities category
      final expense = ExpenseData(
        date: selectedDisbursementDate,
        category: 'Utilities',
        description: 'Payroll - $teamName Salary',
        amount: actualAmount,
        vendor: teamName,
        notes: 'Period: ${DateFormat('MMM dd, yyyy').format(selectedDisbursementStartDate)} - ${DateFormat('MMM dd, yyyy').format(selectedDisbursementEndDate)}\n${bookingsInPeriod.length} job(s) completed',
        addedBy: 'Admin',
        createdAt: DateTime.now(),
      );
      await ExpenseManager.addExpense(expense);

      // Reload data to update status
      await _loadPayrollData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('₱${actualAmount.toStringAsFixed(2)} disbursed to $teamName (${bookingsInPeriod.length} jobs)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error disbursing salary: $e')),
        );
      }
    }
  }

  Future<void> _resetAllCommissions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Commissions'),
        content: const Text(
          'This will reset all team commissions to ₱0.00 in the Bookings collection. This action cannot be undone.\n\nAre you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);

      final resetCount = await CommissionResetter.resetAllCommissions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully reset $resetCount commission records'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload data
        await _loadPayrollData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error resetting commissions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Delete All Data'),
        content: const Text(
          'This will PERMANENTLY DELETE all:\n\n• Transactions\n• Bookings\n\nThis action CANNOT be undone!\n\nAre you absolutely sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade900,
              foregroundColor: Colors.white,
            ),
            child: const Text('DELETE ALL'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);

      final results = await DataDeleter.deleteAllTransactionsAndBookings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Deleted ${results['transactions']} transactions and ${results['bookings']} bookings',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );

        await _loadPayrollData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error deleting data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadPayrollData() async {
    setState(() => _isLoading = true);

    try {
      // Get all disbursement records
      final disbursementsSnapshot = await FirebaseFirestore.instance
          .collection('PayrollDisbursements')
          .get();

      // Track disbursement status for each team
      Map<String, bool> teamHasDisbursement = {'Team A': false, 'Team B': false};
      Map<String, DateTime?> teamLatestDisbursement = {'Team A': null, 'Team B': null};

      for (final doc in disbursementsSnapshot.docs) {
        final data = doc.data();
        final team = data['teamName'] as String?;
        final isDisbursed = data['isDisbursed'] as bool? ?? false;
        final disbursedAt = (data['disbursedAt'] as Timestamp?)?.toDate();

        if (team != null && isDisbursed) {
          teamHasDisbursement[team] = true;

          // Track the latest disbursement date
          if (disbursedAt != null) {
            if (teamLatestDisbursement[team] == null ||
                disbursedAt.isAfter(teamLatestDisbursement[team]!)) {
              teamLatestDisbursement[team] = disbursedAt;
            }
          }
        }
      }

      // Query completed bookings only
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('Bookings')
          .where('status', isEqualTo: 'completed')
          .get();

      Map<String, double> commissions = {'Team A': 0.0, 'Team B': 0.0};
      Map<String, int> counts = {'Team A': 0, 'Team B': 0};
      for (final doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final team = data['assignedTeam'] as String?;
        final commission = (data['teamCommission'] as num?)?.toDouble() ?? 0.0;
        final isPaid = data['salaryDisbursed'] as bool? ?? false;
        final source = data['source'] as String? ?? '';

        if (source == 'import') continue;
        if (team == null || !commissions.containsKey(team) || isPaid) continue;

        commissions[team] = commissions[team]! + commission;
        counts[team] = counts[team]! + 1;
      }
      Map<String, bool> finalDisbursementStatus = {
        'Team A': commissions['Team A'] == 0.0 && teamHasDisbursement['Team A']!,
        'Team B': commissions['Team B'] == 0.0 && teamHasDisbursement['Team B']!,
      };

      setState(() {
        _teamCommissions = commissions;
        _teamBookingCounts = counts;
        _teamDisbursementStatus = finalDisbursementStatus;
        _teamDisbursementDate = teamLatestDisbursement;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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
                        _teamDisbursementStatus['Team A']!,
                        _teamDisbursementDate['Team A'],
                      ),
                      const SizedBox(height: 12),
                      _buildTeamCard(
                        'Team B',
                        _teamCommissions['Team B']!,
                        _teamBookingCounts['Team B']!,
                        _teamDisbursementStatus['Team B']!,
                        _teamDisbursementDate['Team B'],
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
      child: Row(
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
                      '$totalJobs total jobs',
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
            onPressed: _deleteAllData,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade900,
              backgroundColor: Colors.red.shade100,
              side: BorderSide(color: Colors.red.shade900, width: 1.5),
            ),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Delete All'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _resetAllCommissions,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              backgroundColor: Colors.red.shade50,
              side: BorderSide(color: Colors.red.shade700, width: 1.5),
            ),
            icon: const Icon(Icons.restore, size: 18),
            label: const Text('Reset All'),
          ),
          const SizedBox(width: 8),
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
    );
  }

  Widget _buildTeamCard(String teamName, double commission, int jobCount, bool isDisbursed, DateTime? disbursementDate) {
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
                        'Pending Commission',
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
                        'Pending Amount',
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
                        'Unpaid Jobs',
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
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            // Disbursement Status and Button
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            commission == 0.0 ? Icons.check_circle : Icons.pending,
                            color: commission == 0.0 ? Colors.green : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            commission == 0.0 ? 'All Paid' : 'Has Pending',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: commission == 0.0 ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      if (disbursementDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Last disbursement: ${DateFormat('MMM dd, yyyy').format(disbursementDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: (commission == 0.0) ? null : () => _disburseSalary(teamName, commission),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (commission == 0.0) ? Colors.grey : Colors.yellow.shade700,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                  ),
                  icon: Icon((commission == 0.0) ? Icons.check : Icons.payment),
                  label: Text(
                    (commission == 0.0) ? 'No Pending Amount' : 'Disburse Salary',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}