import 'package:flutter/material.dart';
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

    return Column(
        children: [
          _buildQuickActions(lowStockCount),
          _buildFilters(categories, isWide),
          _buildSummaryCards(isWide),
          Expanded(
            child: _buildInventoryList(isWide),
          ),
        ],
      );
  }

  Widget _buildQuickActions(int lowStockCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showAddItemDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow.shade700,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 3,
              ),
              icon: const Icon(Icons.add, weight: 600),
              label: const Text('Add New Item', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          if (lowStockCount > 0)
            ElevatedButton.icon(
              onPressed: () => _showLowStockAlert(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: Badge(
                label: Text('$lowStockCount'),
                child: const Icon(Icons.warning),
              ),
              label: const Text('Low Stock'),
            ),
        ],
      ),
    );
  }

  Widget _buildFilters(List<String> categories, bool isWide) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search items...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _selectedCategory,
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(bool isWide) {
    final totalItems = _allItems.length;
    final lowStockItems = _allItems.where((item) => item.isLowStock).length;
    final totalValue = _allItems.fold<double>(
      0.0,
      (sum, item) => sum + (item.currentStock * item.unitPrice),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Total Items',
              totalItems.toString(),
              Icons.inventory,
              Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              'Low Stock',
              lowStockItems.toString(),
              Icons.warning,
              Colors.orange.shade700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              'Total Value',
              '₱${totalValue.toStringAsFixed(0)}',
              Icons.attach_money,
              Colors.yellow.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: item.isLowStock ? Colors.red : Colors.green,
              child: Icon(
                item.isLowStock ? Icons.warning : Icons.check,
                color: Colors.white,
              ),
            ),
            title: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Category: ${item.category}'),
                Text('Stock: ${item.currentStock} ${item.unit}'),
                if (item.isLowStock)
                  Text(
                    'LOW STOCK! (Min: ${item.minStock})',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₱${item.unitPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text('per ${item.unit}'),
                  ],
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showEditItemDialog(item);
                        break;
                      case 'adjust':
                        _showAdjustStockDialog(item);
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
                      value: 'adjust',
                      child: ListTile(
                        leading: Icon(Icons.tune),
                        title: Text('Adjust Stock'),
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

  void _showAddItemDialog() {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final stockController = TextEditingController();
    final minStockController = TextEditingController();
    final priceController = TextEditingController();
    final unitController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Item'),
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
                controller: stockController,
                decoration: const InputDecoration(labelText: 'Current Stock'),
                keyboardType: TextInputType.number,
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
                decoration: const InputDecoration(labelText: 'Unit (e.g., bottles, pieces)'),
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
              if (nameController.text.isNotEmpty &&
                  categoryController.text.isNotEmpty &&
                  stockController.text.isNotEmpty &&
                  minStockController.text.isNotEmpty &&
                  priceController.text.isNotEmpty &&
                  unitController.text.isNotEmpty) {

                try {
                  final currentStock = int.tryParse(stockController.text);
                  final minStock = int.tryParse(minStockController.text);
                  final unitPrice = double.tryParse(priceController.text);

                  if (currentStock == null || minStock == null || unitPrice == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter valid numbers for stock and price')),
                      );
                    }
                    return;
                  }

                  final newItem = InventoryItem(
                    id: '',
                    name: nameController.text.trim(),
                    category: categoryController.text.trim(),
                    currentStock: currentStock,
                    minStock: minStock,
                    unitPrice: unitPrice,
                    unit: unitController.text.trim(),
                    lastUpdated: DateTime.now(),
                  );

                  await InventoryManager.addItem(newItem);
                  await _loadData();
                  if (mounted) Navigator.pop(context);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Item added successfully!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding item: $e')),
                    );
                  }
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in all fields')),
                  );
                }
              }
            },
            child: const Text('Add'),
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

  void _showAdjustStockDialog(InventoryItem item) {
    final stockController = TextEditingController(text: item.currentStock.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Adjust Stock - ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Stock: ${item.currentStock} ${item.unit}'),
            const SizedBox(height: 16),
            TextField(
              controller: stockController,
              decoration: const InputDecoration(labelText: 'New Stock Amount'),
              keyboardType: TextInputType.number,
            ),
          ],
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
                  await InventoryManager.updateStock(item.id, newStock);
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
}