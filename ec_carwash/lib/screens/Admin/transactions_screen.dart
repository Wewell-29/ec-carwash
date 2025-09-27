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
  String _selectedFilter = 'all'; // all, today, week, month
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

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedFilter = 'custom';
      });
      _loadTransactions();
    }
  }

  Color _getSourceColor(String? source) {
    switch (source) {
      case 'booking':
        return Colors.blue;
      case 'pos':
      default:
        return Colors.green;
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
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          // Summary Cards and Filters
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: Colors.green,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.payments, color: Colors.white, size: 24),
                              const SizedBox(height: 8),
                              Text(
                                '₱${totalRevenue.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Total Revenue',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Card(
                        color: Colors.blue,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.receipt_long, color: Colors.white, size: 24),
                              const SizedBox(height: 8),
                              Text(
                                totalTransactions.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Transactions',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Filter buttons
                Row(
                  children: [
                    _buildFilterChip('All', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Today', 'today'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Week', 'week'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Month', 'month'),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(_selectedFilter == 'custom' && _startDate != null
                          ? 'Custom Range'
                          : 'Pick Range'),
                      selected: _selectedFilter == 'custom',
                      onSelected: (selected) => _showDateRangePicker(),
                      selectedColor: Colors.yellow.shade700,
                      checkmarkColor: Colors.black,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadTransactions,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Transactions List
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
                        padding: const EdgeInsets.all(16),
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          final transaction = _transactions[index];
                          return _buildTransactionCard(transaction);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedFilter = value);
        _loadTransactions();
      },
      selectedColor: Colors.yellow.shade700,
      checkmarkColor: Colors.black,
    );
  }

  Widget _buildTransactionCard(TransactionData transaction) {
    final sourceColor = _getSourceColor(transaction.source);
    final sourceIcon = _getSourceIcon(transaction.source);
    final customerName = transaction.customer['name'] ?? 'Unknown Customer';
    final plateNumber = transaction.customer['plateNumber'] ?? 'N/A';
    final timeFormatted = transaction.time['formatted'] ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with source and transaction ID
            Row(
              children: [
                Icon(sourceIcon, color: sourceColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  transaction.source?.toUpperCase() ?? 'POS',
                  style: TextStyle(
                    color: sourceColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  'TXN #${transaction.id?.substring(0, 8) ?? 'N/A'}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Customer and transaction info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Plate: $plateNumber',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      if (transaction.bookingId != null)
                        Text(
                          'Booking: ${transaction.bookingId?.substring(0, 8)}',
                          style: TextStyle(color: Colors.blue.shade600, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('MMM dd, yyyy').format(transaction.transactionAt),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      timeFormatted,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Items
            const Text(
              'Items:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            ...transaction.items.map((item) {
              final code = item['serviceCode'] ?? 'N/A';
              final vehicleType = item['vehicleType'] ?? 'N/A';
              final quantity = item['quantity'] ?? 1;
              final subtotal = (item['subtotal'] ?? 0).toDouble();

              return Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('• $code ($vehicleType) x$quantity'),
                    ),
                    Text(
                      '₱${subtotal.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            // Payment details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text(
                        '₱${transaction.total.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Cash:'),
                      const Spacer(),
                      Text('₱${transaction.cash.toStringAsFixed(2)}'),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Change:'),
                      const Spacer(),
                      Text('₱${transaction.change.toStringAsFixed(2)}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}