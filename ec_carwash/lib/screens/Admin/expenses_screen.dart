import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ec_carwash/data_models/expense_data.dart';
import 'package:ec_carwash/data_models/inventory_data.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<ExpenseData> _expenses = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _selectedFilter = 'today'; // today, week, month, all
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    try {
      DateTime? start;
      DateTime? end;

      if (_selectedFilter == 'today') {
        final today = DateTime.now();
        start = DateTime(today.year, today.month, today.day);
        end = DateTime(today.year, today.month, today.day, 23, 59, 59);
      } else if (_selectedFilter == 'week') {
        end = DateTime.now();
        start = end.subtract(const Duration(days: 7));
      } else if (_selectedFilter == 'month') {
        final now = DateTime.now();
        start = DateTime(now.year, now.month - 1, now.day);
        end = now;
      } else if (_selectedFilter == 'custom' && _startDate != null && _endDate != null) {
        start = _startDate;
        end = _endDate;
      }

      final expenses = await ExpenseManager.getExpenses(
        category: _selectedCategory,
        startDate: start,
        endDate: end,
        limit: 100,
      );

      setState(() {
        _expenses = expenses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading expenses: $e')),
        );
      }
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Utilities':
        return Icons.flash_on;
      case 'Maintenance':
        return Icons.build;
      case 'Supplies':
        return Icons.inventory;
      case 'Miscellaneous':
      default:
        return Icons.more_horiz;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalExpenses = _expenses.fold<double>(0.0, (total, expense) => total + expense.amount);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildFilters(totalExpenses),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _expenses.isEmpty
                    ? const Center(child: Text('No expenses found'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _expenses.length,
                        itemBuilder: (context, index) {
                          return _buildExpenseCard(_expenses[index]);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseDialog(),
        backgroundColor: Colors.yellow.shade700,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildFilters(double totalExpenses) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              // Total Expenses Badge
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
                    const Icon(Icons.money_off, color: Colors.black87, size: 20),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₱${totalExpenses.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_expenses.length} expenses',
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
              // Category Filters
              _buildCategoryChip('All', 'All'),
              const SizedBox(width: 8),
              _buildCategoryChip('Utilities', 'Utilities'),
              const SizedBox(width: 8),
              _buildCategoryChip('Maintenance', 'Maintenance'),
              const SizedBox(width: 8),
              _buildCategoryChip('Supplies', 'Supplies'),
              const SizedBox(width: 8),
              _buildCategoryChip('Misc', 'Miscellaneous'),
              const Spacer(),
              // QA Requirement #10: Print Data History button
              OutlinedButton.icon(
                onPressed: _expenses.isEmpty ? null : _printExpenseHistory,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  backgroundColor: Colors.yellow.shade50,
                  side: const BorderSide(color: Colors.black87, width: 1.5),
                ),
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Print History'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _loadExpenses,
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
              _buildDateChip('Today', 'today'),
              const SizedBox(width: 8),
              _buildDateChip('Week', 'week'),
              const SizedBox(width: 8),
              _buildDateChip('Month', 'month'),
              const SizedBox(width: 8),
              _buildDateChip('All', 'all'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, String value) {
    final isSelected = _selectedCategory == value;
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
        setState(() => _selectedCategory = value);
        _loadExpenses();
      },
      selectedColor: Colors.yellow.shade700,
      backgroundColor: Colors.grey.shade200,
      side: BorderSide(
        color: isSelected ? Colors.black87 : Colors.transparent,
        width: 1.5,
      ),
    );
  }

  Widget _buildDateChip(String label, String value) {
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
        _loadExpenses();
      },
      selectedColor: Colors.yellow.shade700,
      backgroundColor: Colors.grey.shade200,
      side: BorderSide(
        color: isSelected ? Colors.black87 : Colors.transparent,
        width: 1.5,
      ),
    );
  }

  Widget _buildExpenseCard(ExpenseData expense) {
    final categoryIcon = _getCategoryIcon(expense.category);

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
            child: Icon(categoryIcon, color: Colors.black87, size: 24),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    expense.description,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 17,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '₱${expense.amount.toStringAsFixed(2)}',
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade700,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.black87, width: 0.5),
                  ),
                  child: Text(
                    expense.category,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat('MMM dd, yyyy').format(expense.date),
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ),
                if (expense.quantity != null && expense.quantity! > 0)
                  Text(
                    'Qty: ${expense.quantity}',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'delete':
                _showDeleteConfirmation(expense);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete),
                title: Text('Delete'),
              ),
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
                if (expense.vendor != null && expense.vendor!.isNotEmpty) ...[
                  Row(
                    children: [
                      const Text(
                        'Vendor:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Text(expense.vendor!, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (expense.notes != null && expense.notes!.isNotEmpty) ...[
                  const Text(
                    'Notes:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(expense.notes!, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 8),
                ],
                Text(
                  'Added by ${expense.addedBy} on ${DateFormat('MMM dd, yyyy HH:mm').format(expense.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog() async {
    DateTime selectedDate = DateTime.now();
    String selectedCategory = 'Utilities';
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final quantityController = TextEditingController();
    final vendorController = TextEditingController();
    final notesController = TextEditingController();

    // Load inventory items for Supplies dropdown
    List<String> inventoryItems = [];
    String? selectedInventoryItem;

    // Store full inventory for later use
    List<InventoryItem> fullInventory = [];
    try {
      fullInventory = await InventoryManager.getItems();
      inventoryItems = fullInventory.map((item) => item.name).toList();
    } catch (e) {
      debugPrint('Error loading inventory: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Picker
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today, color: Colors.black87),
                      title: const Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                      trailing: TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                        child: const Text('Change'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: ['Utilities', 'Maintenance', 'Supplies', 'Miscellaneous']
                          .map((category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedCategory = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description - Dropdown for Supplies, TextField otherwise
                    if (selectedCategory == 'Supplies') ...[
                      DropdownButtonFormField<String>(
                        value: selectedInventoryItem,
                        decoration: const InputDecoration(
                          labelText: 'Select Item *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.inventory),
                        ),
                        items: inventoryItems.map((item) => DropdownMenuItem(
                          value: item,
                          child: Text(item),
                        )).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedInventoryItem = value;
                            if (value != null) {
                              descriptionController.text = value;
                            }
                          });
                        },
                      ),
                    ] else ...[
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Amount and Quantity Row
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: amountController,
                            decoration: const InputDecoration(
                              labelText: 'Amount *',
                              border: OutlineInputBorder(),
                              prefixText: '₱',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: quantityController,
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Vendor
                    TextField(
                      controller: vendorController,
                      decoration: const InputDecoration(
                        labelText: 'Vendor',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.store),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Validation
                  if (descriptionController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a description')),
                    );
                    return;
                  }

                  final amount = double.tryParse(amountController.text.trim());
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid amount')),
                    );
                    return;
                  }

                  final quantity = quantityController.text.trim().isNotEmpty
                      ? int.tryParse(quantityController.text.trim())
                      : null;

                  try {
                    // Find inventory item if supplies category
                    String? inventoryItemId;
                    String? inventoryItemName;
                    if (selectedCategory == 'Supplies' && selectedInventoryItem != null) {
                      final item = fullInventory.firstWhere(
                        (inv) => inv.name == selectedInventoryItem,
                        orElse: () => fullInventory.first,
                      );
                      inventoryItemId = item.id;
                      inventoryItemName = item.name;
                    }

                    // Create expense
                    final expense = ExpenseData(
                      date: selectedDate,
                      category: selectedCategory,
                      description: descriptionController.text.trim(),
                      amount: amount,
                      quantity: quantity,
                      vendor: vendorController.text.trim().isNotEmpty
                          ? vendorController.text.trim()
                          : null,
                      notes: notesController.text.trim().isNotEmpty
                          ? notesController.text.trim()
                          : null,
                      inventoryItemId: inventoryItemId,
                      inventoryItemName: inventoryItemName,
                      addedBy: 'Admin', // TODO: Get from auth
                      createdAt: DateTime.now(),
                    );

                    await ExpenseManager.addExpense(expense);

                    // Update inventory if supplies category
                    if (selectedCategory == 'Supplies' && inventoryItemId != null && quantity != null && quantity > 0) {
                      final item = fullInventory.firstWhere((inv) => inv.id == inventoryItemId);
                      await InventoryManager.updateStock(
                        inventoryItemId,
                        item.currentStock + quantity,
                      );
                    }

                    await _loadExpenses();
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            selectedCategory == 'Supplies' && quantity != null
                                ? 'Expense added and inventory updated (+$quantity)'
                                : 'Expense added successfully'
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error adding expense: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow.shade700,
                  foregroundColor: Colors.black87,
                ),
                child: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // QA Requirement #10: Print Data History functionality
  Future<void> _printExpenseHistory() async {
    try {
      final pdf = pw.Document();

      // Calculate total
      final totalExpenses = _expenses.fold<double>(0.0, (total, expense) => total + expense.amount);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'EC CARWASH',
                      style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Balayan Batangas',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Divider(thickness: 2),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'EXPENSE HISTORY',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Category: $_selectedCategory'),
                        pw.Text('Filter: $_selectedFilter'),
                      ],
                    ),
                    pw.Text('Generated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}'),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Total: P${totalExpenses.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Expense Table
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.2),
                  4: const pw.FlexColumnWidth(1),
                },
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _buildTableCell('Date', isHeader: true),
                      _buildTableCell('Description', isHeader: true),
                      _buildTableCell('Category', isHeader: true),
                      _buildTableCell('Vendor', isHeader: true),
                      _buildTableCell('Amount', isHeader: true),
                    ],
                  ),
                  // Data Rows
                  for (final expense in _expenses)
                    pw.TableRow(
                      children: [
                        _buildTableCell(DateFormat('MM/dd/yy').format(expense.date)),
                        _buildTableCell(expense.description),
                        _buildTableCell(expense.category),
                        _buildTableCell(expense.vendor ?? '-'),
                        _buildTableCell('P${expense.amount.toStringAsFixed(2)}'),
                      ],
                    ),
                ],
              ),
            ];
          },
        ),
      );

      // Print or share the PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing expense history: $e')),
        );
      }
    }
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
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

  void _showDeleteConfirmation(ExpenseData expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to delete "${expense.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ExpenseManager.deleteExpense(expense.id!);
                await _loadExpenses();
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting expense: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
