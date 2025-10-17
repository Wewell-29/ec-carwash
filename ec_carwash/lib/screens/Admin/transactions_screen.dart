import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TransactionData {
  final String? id;
  final Map<String, dynamic> customer;
  final List<dynamic> services;
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
    required this.services,
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
      services: json['services'] ?? [],
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
                ElevatedButton.icon(
                  onPressed: _transactions.isEmpty ? null : _showPrintDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow.shade700,
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Colors.black87, width: 1.5),
                  ),
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('Print All'),
                ),
                const SizedBox(width: 12),
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
                  '${transaction.services.length} service${transaction.services.length > 1 ? 's' : ''}',
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

                // Customer Information Section
                const Text(
                  'Customer Information:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Name', customerName),
                _buildInfoRow('Plate Number', plateNumber),
                _buildInfoRow('Contact', transaction.customer['contactNumber'] ?? 'N/A'),
                _buildInfoRow('Vehicle Type', transaction.customer['vehicleType'] ?? 'N/A'),
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
                ...transaction.services.map((item) {
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
                // Print Receipt Button
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Amount:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '₱${transaction.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 19,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _printSingleReceipt(transaction),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow.shade700,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      icon: const Icon(Icons.print),
                      label: const Text('Print Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printSingleReceipt(TransactionData transaction) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'EC CARWASH',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text('Balayan Batangas', style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 8),
                pw.Divider(),
                pw.SizedBox(height: 8),
                pw.Text('RECEIPT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text('TXN: ${transaction.id?.substring(0, 12) ?? 'N/A'}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Date: ${DateFormat('MMM dd, yyyy HH:mm').format(transaction.transactionAt)}', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 8),
                pw.Divider(),
                pw.SizedBox(height: 8),
                pw.Text('Customer: ${transaction.customer['name'] ?? 'N/A'}', style: const pw.TextStyle(fontSize: 12)),
                pw.Text('Plate: ${transaction.customer['plateNumber'] ?? 'N/A'}', style: const pw.TextStyle(fontSize: 12)),
                pw.Text('Vehicle: ${transaction.customer['vehicleType'] ?? 'N/A'}', style: const pw.TextStyle(fontSize: 12)),
                pw.Text('Contact: ${transaction.customer['contactNumber'] ?? 'N/A'}', style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 8),
                pw.Divider(),
                pw.SizedBox(height: 8),
                pw.Text('SERVICES:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                ...transaction.services.map((service) {
                  final code = service['serviceCode'] ?? 'N/A';
                  final vehicleType = service['vehicleType'] ?? 'N/A';
                  final quantity = service['quantity'] ?? 1;
                  final subtotal = (service['subtotal'] ?? 0).toDouble();
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(child: pw.Text('$code ($vehicleType) x$quantity', style: const pw.TextStyle(fontSize: 11))),
                        pw.Text('P${subtotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 11)),
                      ],
                    ),
                  );
                }),
                pw.SizedBox(height: 8),
                pw.Divider(),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('P${transaction.total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Cash:', style: const pw.TextStyle(fontSize: 12)),
                    pw.Text('P${transaction.cash.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Change:', style: const pw.TextStyle(fontSize: 12)),
                    pw.Text('P${transaction.change.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Divider(),
                pw.SizedBox(height: 8),
                pw.Center(child: pw.Text('Thank you for your business!', style: const pw.TextStyle(fontSize: 10))),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing receipt: $e')),
        );
      }
    }
  }

  void _showPrintDialog() {
    showDialog(
      context: context,
      builder: (context) => _PrintOptionsDialog(
        onPrint: _printAllTransactions,
        currentFilter: _selectedFilter,
      ),
    );
  }

  Future<void> _printAllTransactions({int? month, int? year}) async {
    try {
      List<TransactionData> transactionsToPrint = _transactions;

      // If month/year specified, filter transactions
      if (month != null && year != null) {
        transactionsToPrint = _transactions.where((txn) {
          return txn.transactionAt.month == month && txn.transactionAt.year == year;
        }).toList();
      }

      if (transactionsToPrint.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No transactions to print')),
          );
        }
        return;
      }

      final pdf = pw.Document();
      final totalRevenue = transactionsToPrint.fold<double>(0.0, (total, txn) => total + txn.total);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('EC CARWASH', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Balayan Batangas', style: const pw.TextStyle(fontSize: 14)),
                    pw.SizedBox(height: 8),
                    pw.Divider(thickness: 2),
                    pw.SizedBox(height: 8),
                    pw.Text('TRANSACTION SUMMARY', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    if (month != null && year != null)
                      pw.Text('Period: ${DateFormat('MMMM yyyy').format(DateTime(year, month))}')
                    else
                      pw.Text('Filter: $_selectedFilter'),
                    pw.Text('Generated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}'),
                    pw.SizedBox(height: 8),
                    pw.Text('Total Transactions: ${transactionsToPrint.length}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Total Revenue: P${totalRevenue.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.2),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _buildPdfTableCell('Date', isHeader: true),
                      _buildPdfTableCell('Customer', isHeader: true),
                      _buildPdfTableCell('Plate', isHeader: true),
                      _buildPdfTableCell('Services', isHeader: true),
                      _buildPdfTableCell('Amount', isHeader: true),
                    ],
                  ),
                  for (final txn in transactionsToPrint)
                    pw.TableRow(
                      children: [
                        _buildPdfTableCell(DateFormat('MM/dd/yy').format(txn.transactionAt)),
                        _buildPdfTableCell(txn.customer['name'] ?? 'N/A'),
                        _buildPdfTableCell(txn.customer['plateNumber'] ?? 'N/A'),
                        _buildPdfTableCell('${txn.services.length} service(s)'),
                        _buildPdfTableCell('P${txn.total.toStringAsFixed(2)}'),
                      ],
                    ),
                ],
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing transactions: $e')),
        );
      }
    }
  }

  pw.Widget _buildPdfTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}

// Print Options Dialog Widget
class _PrintOptionsDialog extends StatefulWidget {
  final Function({int? month, int? year}) onPrint;
  final String currentFilter;

  const _PrintOptionsDialog({
    required this.onPrint,
    required this.currentFilter,
  });

  @override
  State<_PrintOptionsDialog> createState() => _PrintOptionsDialogState();
}

class _PrintOptionsDialogState extends State<_PrintOptionsDialog> {
  int? _selectedMonth;
  int? _selectedYear;
  bool _useCustomDate = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Print Transaction Summary', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Filter: ${widget.currentFilter}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Select specific month/year'),
              value: _useCustomDate,
              onChanged: (value) {
                setState(() {
                  _useCustomDate = value;
                  if (!value) {
                    _selectedMonth = null;
                    _selectedYear = null;
                  }
                });
              },
            ),
            if (_useCustomDate) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Month',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedMonth,
                      items: List.generate(12, (index) {
                        final month = index + 1;
                        return DropdownMenuItem(
                          value: month,
                          child: Text(DateFormat('MMMM').format(DateTime(2000, month))),
                        );
                      }),
                      onChanged: (value) => setState(() => _selectedMonth = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Year',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedYear,
                      items: List.generate(5, (index) {
                        final year = DateTime.now().year - index;
                        return DropdownMenuItem(
                          value: year,
                          child: Text(year.toString()),
                        );
                      }),
                      onChanged: (value) => setState(() => _selectedYear = value),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (_useCustomDate && (_selectedMonth == null || _selectedYear == null)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select both month and year')),
              );
              return;
            }
            Navigator.pop(context);
            widget.onPrint(month: _selectedMonth, year: _selectedYear);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.yellow.shade700,
            foregroundColor: Colors.black87,
          ),
          icon: const Icon(Icons.print),
          label: const Text('Print', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}