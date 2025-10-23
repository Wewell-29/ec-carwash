import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ec_carwash/data_models/inventory_data.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<InventoryItem> _allItems = [];
  List<String> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final items = await InventoryManager.getItems();
      final categories = await InventoryManager.getCategories();
      setState(() {
        _allItems = items;
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading inventory: $e')),
        );
      }
    }
  }

  List<InventoryItem> get _filteredItems {
    List<InventoryItem> items = _allItems;

    if (_selectedCategory != 'All') {
      items = items.where((item) => item.category == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      items = items.where((item) =>
        item.name.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    // Sort by stock level: lowest stock first, then by stock percentage
    items.sort((a, b) {
      double aPercentage = a.currentStock / a.minStock;
      double bPercentage = b.currentStock / b.minStock;

      // Low stock items first
      if (a.isLowStock && !b.isLowStock) return -1;
      if (!a.isLowStock && b.isLowStock) return 1;

      // Among low stock items, sort by percentage (lowest first)
      if (a.isLowStock && b.isLowStock) {
        return aPercentage.compareTo(bPercentage);
      }

      // Among normal stock items, sort by percentage (lowest first)
      return aPercentage.compareTo(bPercentage);
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isWide = MediaQuery.of(context).size.width > 800;
    final categories = ['All', ..._categories];
    final lowStockItems = _allItems.where((item) => item.isLowStock).toList();
    final lowStockCount = lowStockItems.length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildFilters(categories, isWide, lowStockCount),
          Expanded(
            child: _buildInventoryList(isWide),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddItemDialog(),
        backgroundColor: Colors.yellow.shade700,
        foregroundColor: Colors.black87,
        icon: const Icon(Icons.add),
        label: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildFilters(List<String> categories, bool isWide, int lowStockCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search items...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  underline: const SizedBox(),
                  hint: const Text('Category'),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                  },
                  items: categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 12),
              if (lowStockCount > 0)
                ElevatedButton.icon(
                  onPressed: () => _showLowStockAlert(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow.shade700,
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Colors.black87, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    elevation: 2,
                  ),
                  icon: Badge(
                    label: Text('$lowStockCount', style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.black87,
                    child: const Icon(Icons.warning),
                  ),
                  label: const Text('Low Stock', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _showLogHistory(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  backgroundColor: Colors.yellow.shade50,
                  side: const BorderSide(color: Colors.black87, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                ),
                icon: const Icon(Icons.history),
                label: const Text('History', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryList(bool isWide) {
    final items = _filteredItems;

    if (items.isEmpty) {
      return const Center(
        child: Text('No items found'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.yellow.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.black87, width: 1.5),
          ),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black87, width: 1),
              ),
              child: CircleAvatar(
                backgroundColor: item.isLowStock ? Colors.yellow.shade700 : Colors.yellow.shade100,
                child: Icon(
                  item.isLowStock ? Icons.warning : Icons.check_circle,
                  color: Colors.black87,
                ),
              ),
            ),
            title: Text(
              item.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 17,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  'Category: ${item.category}',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 15),
                    children: [
                      TextSpan(
                        text: 'Stock: ',
                        style: TextStyle(color: Colors.black.withValues(alpha: 0.7)),
                      ),
                      TextSpan(
                        text: '${item.currentStock}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                      TextSpan(
                        text: ' ${item.unit}',
                        style: TextStyle(color: Colors.black.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
                if (item.isLowStock)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.yellow.shade700,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black87, width: 1),
                    ),
                    child: Text(
                      'LOW STOCK! (Min: ${item.minStock})',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Eye-catching Withdraw button
                ElevatedButton.icon(
                  onPressed: () => _showWithdrawStockDialog(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow.shade700,
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Colors.black87, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    elevation: 3,
                  ),
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  label: const Text(
                    'Withdraw',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showEditItemDialog(item);
                        break;
                      case 'addStock':
                        _showAddStockDialog(item);
                        break;
                      case 'adjust':
                        _showAdjustStockDialog(item);
                        break;
                      case 'history':
                        _showItemHistory(item);
                        break;
                      case 'delete':
                        _showDeleteConfirmation(item);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Edit'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'addStock',
                      child: ListTile(
                        leading: Icon(Icons.add_circle),
                        title: Text('Add Stock'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'adjust',
                      child: ListTile(
                        leading: Icon(Icons.tune),
                        title: Text('Adjust Stock'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'history',
                      child: ListTile(
                        leading: Icon(Icons.history),
                        title: Text('View History'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete),
                        title: Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLowStockAlert() {
    final lowStockItems = _allItems.where((item) => item.isLowStock).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Low Stock Alert'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: lowStockItems.map((item) {
              return ListTile(
                leading: const Icon(Icons.warning, color: Colors.red),
                title: Text(item.name),
                subtitle: Text('Current: ${item.currentStock}, Min: ${item.minStock}'),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEditItemDialog(InventoryItem item) {
    final nameController = TextEditingController(text: item.name);
    final categoryController = TextEditingController(text: item.category);
    final minStockController = TextEditingController(text: item.minStock.toString());
    final priceController = TextEditingController(text: item.unitPrice.toString());
    final unitController = TextEditingController(text: item.unit);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              TextField(
                controller: minStockController,
                decoration: const InputDecoration(labelText: 'Minimum Stock'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Unit Price'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(labelText: 'Unit'),
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
            onPressed: () async {
              final updatedItem = item.copyWith(
                name: nameController.text,
                category: categoryController.text,
                minStock: int.parse(minStockController.text),
                unitPrice: double.parse(priceController.text),
                unit: unitController.text,
                lastUpdated: DateTime.now(),
              );

              try {
                await InventoryManager.updateItem(item.id, updatedItem);
                await _loadData();
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating item: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddStockDialog(InventoryItem item) {
    final quantityController = TextEditingController();
    final staffNameController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Stock - ${item.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current Stock: ${item.currentStock} ${item.unit}'),
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity to Add',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: staffNameController,
                decoration: const InputDecoration(
                  labelText: 'Staff Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
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
            onPressed: () async {
              final quantity = int.tryParse(quantityController.text);
              final staffName = staffNameController.text.trim();

              if (quantity == null || quantity <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid quantity')),
                );
                return;
              }

              if (staffName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter staff name')),
                );
                return;
              }

              try {
                // QA Requirement #9: Add Stock with logging
                await InventoryManager.addStockWithLog(
                  item.id,
                  quantity,
                  staffName,
                  notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                );
                await _loadData();
                if (mounted) Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Stock added successfully!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding stock: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow.shade700,
              foregroundColor: Colors.black87,
            ),
            child: const Text('Add Stock'),
          ),
        ],
      ),
    );
  }

  void _showAdjustStockDialog(InventoryItem item) {
    final stockController = TextEditingController(text: item.currentStock.toString());
    final notesController = TextEditingController(); // QA Requirement #6

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Adjust Stock - ${item.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current Stock: ${item.currentStock} ${item.unit}'),
              const SizedBox(height: 16),
              TextField(
                controller: stockController,
                decoration: const InputDecoration(
                  labelText: 'New Stock Amount',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              // QA Requirement #6: Add Notes field
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 3,
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
            onPressed: () async {
              final newStock = int.tryParse(stockController.text);
              if (newStock != null) {
                try {
                  // Use adjustStockWithLog to log the change with notes
                  await InventoryManager.adjustStockWithLog(
                    item.id,
                    newStock,
                    'Admin', // TODO: Get from auth
                    notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  );
                  await _loadData();
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating stock: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // QA Requirement #5: Add delete item logging to history
                final log = InventoryLog(
                  itemId: item.id,
                  itemName: item.name,
                  quantity: item.currentStock,
                  staffName: 'Admin', // TODO: Get from auth
                  action: 'delete',
                  notes: 'Item deleted from inventory',
                  timestamp: DateTime.now(),
                  stockBefore: item.currentStock,
                  stockAfter: 0,
                );
                await InventoryManager.addLog(log);

                await InventoryManager.removeItem(item.id);
                await _loadData();
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting item: $e')),
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

  void _showWithdrawStockDialog(InventoryItem item) {
    final quantityController = TextEditingController();
    final staffNameController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Withdraw Stock - ${item.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Available Stock: ${item.currentStock} ${item.unit}'),
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity to Withdraw',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: staffNameController,
                decoration: const InputDecoration(
                  labelText: 'Staff Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
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
            onPressed: () async {
              final quantity = int.tryParse(quantityController.text);
              final staffName = staffNameController.text.trim();

              if (quantity == null || quantity <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid quantity')),
                );
                return;
              }

              if (staffName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter staff name')),
                );
                return;
              }

              if (quantity > item.currentStock) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Insufficient stock')),
                );
                return;
              }

              try {
                await InventoryManager.withdrawStock(
                  item.id,
                  quantity,
                  staffName,
                  notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                );
                await _loadData();
                if (mounted) Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Stock withdrawn successfully!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error withdrawing stock: $e')),
                  );
                }
              }
            },
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
  }

  void _showItemHistory(InventoryItem item) async {
    try {
      final logs = await InventoryManager.getLogs(itemId: item.id, limit: 50);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('History - ${item.name}'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: logs.isEmpty
                ? const Center(child: Text('No history found'))
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final isWithdraw = log.action == 'withdraw';
                      final isAdd = log.action == 'add';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: Colors.yellow.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Colors.black87, width: 1.5),
                        ),
                        child: ListTile(
                          leading: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black87, width: 1),
                            ),
                            child: CircleAvatar(
                              backgroundColor: isWithdraw
                                  ? Colors.yellow.shade700
                                  : isAdd
                                      ? Colors.yellow.shade200
                                      : Colors.yellow.shade400,
                              child: Icon(
                                isWithdraw ? Icons.remove_circle : Icons.add_circle,
                                color: Colors.black87,
                                size: 20,
                              ),
                            ),
                          ),
                          title: Text(
                            '${log.action.toUpperCase()} - ${log.quantity} ${item.unit}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              fontSize: 16, // QA Requirement #8: Increased font size
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                'Staff: ${log.staffName}',
                                style: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  fontSize: 15, // QA Requirement #8: Increased font size
                                ),
                              ),
                              Text(
                                '${log.stockBefore} → ${log.stockAfter} ${item.unit}',
                                style: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  fontSize: 15, // QA Requirement #8: Increased font size
                                ),
                              ),
                              if (log.notes != null && log.notes!.isNotEmpty)
                                Text(
                                  'Notes: ${log.notes}',
                                  style: TextStyle(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    fontSize: 14, // QA Requirement #8: Increased font size
                                  ),
                                ),
                              Text(
                                log.timestamp.toString().substring(0, 16),
                                style: TextStyle(
                                  fontSize: 14, // QA Requirement #8: Increased font size (was 12)
                                  color: Colors.black.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: $e')),
        );
      }
    }
  }

  void _showLogHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const InventoryLogHistoryScreen(),
      ),
    );
  }

  void _showAddItemDialog() {
    final nameController = TextEditingController();
    String selectedCategory = 'Cleaning Supplies';
    String selectedUnit = 'bottles';
    final minStockController = TextEditingController();
    final initialStockController = TextEditingController();

    // Predefined categories with 'Others' option (QA Requirement #2)
    final predefinedCategories = [
      'Cleaning Supplies',
      'Wax & Polish',
      'Equipment',
      'Finishing Products',
      'Others',
    ];

    // Predefined units (QA Requirement #3)
    final predefinedUnits = [
      'bottles',
      'pieces',
      'containers',
      'liters',
      'gallons',
      'boxes',
      'packs',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add New Item', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Item Name
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Item Name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory_2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category Dropdown (QA Requirement #2)
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: predefinedCategories
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

                    // Unit Dropdown (QA Requirement #3)
                    DropdownButtonFormField<String>(
                      initialValue: selectedUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unit *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.straighten),
                      ),
                      items: predefinedUnits
                          .map((unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(unit),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedUnit = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Initial Stock and Min Stock Row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: initialStockController,
                            decoration: const InputDecoration(
                              labelText: 'Initial Stock *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: minStockController,
                            decoration: const InputDecoration(
                              labelText: 'Min Stock *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    // Note: Unit Price field removed per QA Requirement #4
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
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter item name')),
                    );
                    return;
                  }

                  final initialStock = int.tryParse(initialStockController.text.trim());
                  if (initialStock == null || initialStock < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter valid initial stock')),
                    );
                    return;
                  }

                  final minStock = int.tryParse(minStockController.text.trim());
                  if (minStock == null || minStock < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter valid minimum stock')),
                    );
                    return;
                  }

                  try {
                    final newItem = InventoryItem(
                      id: '', // Firestore will generate
                      name: nameController.text.trim(),
                      category: selectedCategory,
                      currentStock: initialStock,
                      minStock: minStock,
                      unitPrice: 0.0, // Default to 0 as price is removed from UI
                      unit: selectedUnit,
                      lastUpdated: DateTime.now(),
                    );

                    await InventoryManager.addItem(newItem);
                    await _loadData();
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Item added successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error adding item: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow.shade700,
                  foregroundColor: Colors.black87,
                ),
                child: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Separate screen for full log history
class InventoryLogHistoryScreen extends StatefulWidget {
  const InventoryLogHistoryScreen({super.key});

  @override
  State<InventoryLogHistoryScreen> createState() => _InventoryLogHistoryScreenState();
}

class _InventoryLogHistoryScreenState extends State<InventoryLogHistoryScreen> {
  List<InventoryLog> _logs = [];
  bool _isLoading = true;
  String _filterAction = 'all';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await InventoryManager.getLogs(limit: 200);
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading logs: $e')),
        );
      }
    }
  }

  List<InventoryLog> get _filteredLogs {
    if (_filterAction == 'all') return _logs;
    return _logs.where((log) => log.action == _filterAction).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Log History'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.yellow.shade700,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<String>(
              icon: Icon(Icons.filter_list, color: Colors.yellow.shade700),
              tooltip: 'Filter by action',
              onSelected: (value) {
                setState(() => _filterAction = value);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'all', child: Text('All Actions')),
                const PopupMenuItem(value: 'withdraw', child: Text('Withdrawals')),
                const PopupMenuItem(value: 'add', child: Text('Additions')),
                const PopupMenuItem(value: 'adjust', child: Text('Adjustments')),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredLogs.isEmpty
              ? const Center(child: Text('No logs found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredLogs.length,
                  itemBuilder: (context, index) {
                    final log = _filteredLogs[index];
                    final isWithdraw = log.action == 'withdraw';
                    final isAdd = log.action == 'add';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.yellow.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.black87, width: 1.5),
                      ),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black87, width: 1),
                          ),
                          child: CircleAvatar(
                            backgroundColor: isWithdraw
                                ? Colors.yellow.shade700
                                : isAdd
                                    ? Colors.yellow.shade200
                                    : Colors.yellow.shade400,
                            child: Icon(
                              isWithdraw
                                  ? Icons.remove_circle
                                  : isAdd
                                      ? Icons.add_circle
                                      : Icons.tune,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        title: Text(
                          log.itemName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontSize: 17, // QA Requirement #8: Increased font size
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isWithdraw ? Colors.yellow.shade700 : Colors.yellow.shade200,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.black87, width: 0.5),
                              ),
                              child: Text(
                                '${log.action.toUpperCase()}: ${log.quantity} units',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                  fontSize: 14, // QA Requirement #8: Increased font size (was 12)
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Staff: ${log.staffName}',
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.7),
                                fontSize: 15, // QA Requirement #8: Increased font size
                              ),
                            ),
                            Text(
                              '${log.stockBefore} → ${log.stockAfter}',
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.7),
                                fontSize: 15, // QA Requirement #8: Increased font size
                              ),
                            ),
                            if (log.notes != null && log.notes!.isNotEmpty)
                              Text(
                                'Notes: ${log.notes}',
                                style: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  fontSize: 14, // QA Requirement #8: Increased font size
                                ),
                              ),
                            Text(
                              log.timestamp.toString().substring(0, 16),
                              style: TextStyle(
                                fontSize: 14, // QA Requirement #8: Increased font size (was 12)
                                color: Colors.black.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}