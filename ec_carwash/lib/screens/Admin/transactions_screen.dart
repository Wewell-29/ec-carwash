import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ec_carwash/data_models/unified_transaction_data.dart' as txn;

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<txn.Transaction> _transactions = [];
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
          return txn.Transaction.fromJson(doc.data() as Map<String, dynamic>, doc.id);
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

  Widget _buildCompactTransactionCard(txn.Transaction transaction) {
    final sourceIcon = _getSourceIcon(transaction.source);
    final customerName = transaction.customerName.isNotEmpty
        ? transaction.customerName
        : 'Did Not Specify';
    final plateNumber = transaction.vehiclePlateNumber.isNotEmpty
        ? transaction.vehiclePlateNumber
        : 'N/A';
    final timeFormatted = DateFormat('h:mm a').format(transaction.transactionAt);

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
                    transaction.source.toUpperCase(),
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
                        transaction.source.toUpperCase(),
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
                _buildInfoRow('Contact', transaction.contactNumber ?? 'N/A'),
                _buildInfoRow('Vehicle Type', transaction.vehicleType ?? 'N/A'),
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
                  final code = item.serviceCode;
                  final vehicleType = item.vehicleType;
                  final quantity = item.quantity;
                  final subtotal = item.price * item.quantity;

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

  // UNIFIED THERMAL RECEIPT (same format as POS screen)
  Future<void> _printSingleReceipt(txn.Transaction transaction) async {
    try {
      final pdf = pw.Document();

      // Try to load fonts, fallback to default
      pw.Font? regularFont;
      pw.Font? boldFont;
      try {
        regularFont = pw.Font.ttf(await rootBundle.load("assets/fonts/Roboto-Regular.ttf"));
        boldFont = pw.Font.ttf(await rootBundle.load("assets/fonts/Roboto-Bold.ttf"));
      } catch (e) {
      }

      final transactionId = transaction.id?.substring(0, 12) ?? 'N/A';
      final dateStr = DateFormat('yyyy-MM-dd').format(transaction.transactionAt);
      final timeStr = DateFormat('HH:mm').format(transaction.transactionAt);
      final customerName = transaction.customerName.isNotEmpty
          ? transaction.customerName
          : 'Did Not Specify';
      final plateNumber = transaction.vehiclePlateNumber.isNotEmpty
          ? transaction.vehiclePlateNumber
          : 'N/A';
      final vehicleType = transaction.vehicleType ?? '';
      final contactNumber = transaction.contactNumber ?? '';

      // Thermal receipt style - 80mm width (226.77 points)
      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(226.77, double.infinity, marginAll: 10),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Header - Business Name
                pw.Text(
                  "EC CARWASH",
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  "Balayan Batangas",
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 8,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  "SALES INVOICE",
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),

                // Divider
                pw.Divider(thickness: 1),

                // Transaction Info
                pw.Container(
                  width: double.infinity,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _receiptRow("TXN ID:", transactionId, boldFont),
                      _receiptRow("Date:", dateStr, regularFont),
                      _receiptRow("Time:", timeStr, regularFont),
                      pw.SizedBox(height: 4),
                      _receiptRow("Customer:", customerName, regularFont),
                      _receiptRow("Plate No:", plateNumber, regularFont),
                      if (contactNumber.isNotEmpty)
                        _receiptRow("Contact:", contactNumber, regularFont),
                      if (vehicleType.isNotEmpty)
                        _receiptRow("Vehicle:", vehicleType, regularFont),
                    ],
                  ),
                ),

                pw.Divider(thickness: 1),

                // Items header
                pw.Container(
                  width: double.infinity,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          "ITEM",
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Container(
                        width: 25,
                        child: pw.Text(
                          "QTY",
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Container(
                        width: 45,
                        child: pw.Text(
                          "PRICE",
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Container(
                        width: 50,
                        child: pw.Text(
                          "AMOUNT",
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.Container(
                  width: double.infinity,
                  height: 0.5,
                  color: PdfColors.black,
                ),

                // Items
                ...transaction.services.map((item) {
                  final price = item.price;
                  final qty = item.quantity;
                  final subtotal = price * qty;
                  final serviceName = item.serviceName.isNotEmpty
                      ? item.serviceName
                      : item.serviceCode;
                  final serviceCategory = item.vehicleType;

                  return pw.Column(
                    children: [
                      pw.SizedBox(height: 4),
                      pw.Container(
                        width: double.infinity,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            // Service name
                            pw.Text(
                              serviceName,
                              style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            // Price row with qty, price, amount
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  "  $serviceCategory",
                                  style: pw.TextStyle(
                                    font: regularFont,
                                    fontSize: 7,
                                    color: PdfColors.grey700,
                                  ),
                                ),
                                pw.Row(
                                  children: [
                                    pw.Container(
                                      width: 25,
                                      child: pw.Text(
                                        "$qty",
                                        style: pw.TextStyle(
                                          font: regularFont,
                                          fontSize: 9,
                                        ),
                                        textAlign: pw.TextAlign.center,
                                      ),
                                    ),
                                    pw.Container(
                                      width: 45,
                                      child: pw.Text(
                                        "P${price.toStringAsFixed(2)}",
                                        style: pw.TextStyle(
                                          font: regularFont,
                                          fontSize: 9,
                                        ),
                                        textAlign: pw.TextAlign.right,
                                      ),
                                    ),
                                    pw.Container(
                                      width: 50,
                                      child: pw.Text(
                                        "P${subtotal.toStringAsFixed(2)}",
                                        style: pw.TextStyle(
                                          font: regularFont,
                                          fontSize: 9,
                                        ),
                                        textAlign: pw.TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 4),
                    ],
                  );
                }),

                pw.Divider(thickness: 1),

                // Totals
                pw.Container(
                  width: double.infinity,
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            "SUBTOTAL:",
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: 9,
                            ),
                          ),
                          pw.Text(
                            "P${transaction.total.toStringAsFixed(2)}",
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            "TOTAL:",
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            "P${transaction.total.toStringAsFixed(2)}",
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            "Cash:",
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: 9,
                            ),
                          ),
                          pw.Text(
                            "P${transaction.cash.toStringAsFixed(2)}",
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            "Change:",
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: 9,
                            ),
                          ),
                          pw.Text(
                            "P${transaction.change.toStringAsFixed(2)}",
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.Divider(thickness: 1),

                // Footer
                pw.SizedBox(height: 4),
                pw.Text(
                  "THANK YOU FOR YOUR BUSINESS!",
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  "Please come again",
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 7,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  "This serves as your official receipt",
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 6,
                    fontStyle: pw.FontStyle.italic,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            );
          },
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: "receipt_$transactionId.pdf",
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing receipt: $e')),
        );
      }
    }
  }

  // Helper for thermal receipt row
  pw.Widget _receiptRow(String label, String value, pw.Font? font) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: font,
            fontSize: 8,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: font,
            fontSize: 8,
          ),
        ),
      ],
    );
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
      List<txn.Transaction> transactionsToPrint = _transactions;

      // If month/year specified, filter transactions
      if (month != null && year != null) {
        transactionsToPrint = _transactions.where((t) {
          return t.transactionAt.month == month && t.transactionAt.year == year;
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
      final totalRevenue = transactionsToPrint.fold<double>(0.0, (total, t) => total + t.total);

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
                  0: const pw.FlexColumnWidth(0.9),
                  1: const pw.FlexColumnWidth(1.3),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(0.8),
                  5: const pw.FlexColumnWidth(0.9),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _buildPdfTableCell('Date', isHeader: true),
                      _buildPdfTableCell('Customer', isHeader: true),
                      _buildPdfTableCell('Plate', isHeader: true),
                      _buildPdfTableCell('Services', isHeader: true),
                      _buildPdfTableCell('Team', isHeader: true),
                      _buildPdfTableCell('Amount', isHeader: true),
                    ],
                  ),
                  for (final t in transactionsToPrint)
                    pw.TableRow(
                      children: [
                        _buildPdfTableCell(DateFormat('MM/dd/yy').format(t.transactionAt)),
                        _buildPdfTableCell(t.customerName.isNotEmpty ? t.customerName : 'N/A'),
                        _buildPdfTableCell(t.vehiclePlateNumber.isNotEmpty ? t.vehiclePlateNumber : 'N/A'),
                        _buildPdfTableCell(t.services.map((s) => s.serviceCode).join(', ')),
                        _buildPdfTableCell(t.assignedTeam ?? 'N/A'),
                        _buildPdfTableCell('P${t.total.toStringAsFixed(2)}'),
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