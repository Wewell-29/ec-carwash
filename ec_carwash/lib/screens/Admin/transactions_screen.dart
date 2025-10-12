import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TransactionData {
  final String? id;
  final Map<String, dynamic> customer;
  final List<dynamic> items;
  final double total;
  final double cash;
  final double change;
  final DateTime date;
  final Map<String, dynamic> time;
  final DateTime createdAt;
  final DateTime transactionAt;
  final String status;
  final String? source;
  final String? bookingId;

  TransactionData({
    this.id,
    required this.customer,
    required this.items,
    required this.total,
    required this.cash,
    required this.change,
    required this.date,
    required this.time,
    required this.createdAt,
    required this.transactionAt,
    required this.status,
    this.source,
    this.bookingId,
  });

  factory TransactionData.fromJson(Map<String, dynamic> json, String docId) {
    final date = json['date'] is Timestamp
        ? (json['date'] as Timestamp).toDate()
        : DateTime.parse(json['date'] ?? DateTime.now().toIso8601String());

    final createdAt = json['createdAt'] is Timestamp
        ? (json['createdAt'] as Timestamp).toDate()
        : DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String());

    final transactionAt = json['transactionAt'] is Timestamp
        ? (json['transactionAt'] as Timestamp).toDate()
        : DateTime.parse(json['transactionAt'] ?? DateTime.now().toIso8601String());

    return TransactionData(
      id: docId,
      customer: json['customer'] ?? {},
      items: json['items'] ?? [],
      total: (json['total'] ?? 0).toDouble(),
      cash: (json['cash'] ?? 0).toDouble(),
      change: (json['change'] ?? 0).toDouble(),
      date: date,
      time: json['time'] ?? {},
      createdAt: createdAt,
      transactionAt: transactionAt,
      status: json['status'] ?? 'unknown',
      source: json['source'],
      bookingId: json['bookingId'],
    );
  }
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<TransactionData> _transactions = [];
  bool _isLoading = true;
  String _selectedFilter = 'today'; // Default to today
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      Query query = FirebaseFirestore.instance
          .collection('Transactions')
          .orderBy('transactionAt', descending: true);

      // Apply date filters
      if (_selectedFilter == 'today') {
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
        query = query
            .where('transactionAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('transactionAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
      } else if (_selectedFilter == 'week') {
        final now = DateTime.now();
        final weekAgo = now.subtract(const Duration(days: 7));
        query = query
            .where('transactionAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo));
      } else if (_selectedFilter == 'month') {
        final now = DateTime.now();
        final monthAgo = DateTime(now.year, now.month - 1, now.day);
        query = query
            .where('transactionAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monthAgo));
      } else if (_selectedFilter == 'custom' && _startDate != null && _endDate != null) {
        query = query
            .where('transactionAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!))
            .where('transactionAt', isLessThanOrEqualTo: Timestamp.fromDate(_endDate!));
      }

      final QuerySnapshot snapshot = await query.limit(100).get();

      setState(() {
        _transactions = snapshot.docs.map((doc) {
          return TransactionData.fromJson(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    }
  }

  IconData _getSourceIcon(String? source) {
    switch (source) {
      case 'booking':
        return Icons.calendar_today;
      case 'pos':
      default:
        return Icons.point_of_sale;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalRevenue = _transactions.fold<double>(0.0, (total, txn) => total + txn.total);
    final totalTransactions = _transactions.length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Compact Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Revenue Display (compact)
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
                      const Icon(Icons.payments, color: Colors.black87, size: 20),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₱${totalRevenue.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$totalTransactions transactions',
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
                const SizedBox(width: 16),
                // Filter buttons
                _buildFilterChip('Today', 'today'),
                const SizedBox(width: 8),
                _buildFilterChip('Week', 'week'),
                const SizedBox(width: 8),
                _buildFilterChip('Month', 'month'),
                const SizedBox(width: 8),
                _buildFilterChip('All', 'all'),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _loadTransactions,
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
          ),
          // Compact Transactions Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                    ? const Center(
                        child: Text(
                          'No transactions found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          final transaction = _transactions[index];
                          return _buildCompactTransactionCard(transaction);
                        },
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
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedFilter = value);
        _loadTransactions();
      },
      selectedColor: Colors.yellow.shade700,
      backgroundColor: Colors.grey.shade200,
      side: BorderSide(
        color: isSelected ? Colors.black87 : Colors.transparent,
        width: 1.5,
      ),
    );
  }

  Widget _buildCompactTransactionCard(TransactionData transaction) {
    final sourceIcon = _getSourceIcon(transaction.source);
    final customerName = transaction.customer['name'] ?? 'Unknown Customer';
    final plateNumber = transaction.customer['plateNumber'] ?? 'N/A';
    final timeFormatted = transaction.time['formatted'] ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.yellow.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.black87, width: 1.5),
      ),
      elevation: 2,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        childrenPadding: EdgeInsets.zero,
        leading: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black87, width: 1),
          ),
          child: CircleAvatar(
            backgroundColor: Colors.yellow.shade700,
            radius: 22,
            child: Icon(sourceIcon, color: Colors.black87, size: 24),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    customerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 17,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '₱${transaction.total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Plate: $plateNumber',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '${DateFormat('MMM dd, yyyy').format(transaction.transactionAt)} • $timeFormatted',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade700,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.black87, width: 0.5),
                  ),
                  child: Text(
                    transaction.source?.toUpperCase() ?? 'POS',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${transaction.items.length} item${transaction.items.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.black.withValues(alpha: 0.2), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Transaction ID
                Row(
                  children: [
                    Text(
                      'TXN #${transaction.id?.substring(0, 12) ?? 'N/A'}',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade700,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.black87, width: 0.5),
                      ),
                      child: Text(
                        transaction.source?.toUpperCase() ?? 'POS',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Items
                const Text(
                  'Services:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ...transaction.items.map((item) {
                  final code = item['serviceCode'] ?? 'N/A';
                  final vehicleType = item['vehicleType'] ?? 'N/A';
                  final quantity = item['quantity'] ?? 1;
                  final subtotal = (item['subtotal'] ?? 0).toDouble();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '• $code ($vehicleType) x$quantity',
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.7),
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          '₱${subtotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 24),
                // Total Amount Paid
                Row(
                  children: [
                    const Text(
                      'Total Amount Paid:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade700,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.black87, width: 1.5),
                      ),
                      child: Text(
                        '₱${transaction.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}