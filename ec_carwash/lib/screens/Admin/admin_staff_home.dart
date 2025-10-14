import 'package:flutter/material.dart';
import 'package:ec_carwash/data_models/inventory_data.dart';
import 'package:ec_carwash/data_models/expense_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'pos_screen.dart';
import 'inventory_screen.dart';
import 'expenses_screen.dart';
import 'services_screen.dart';
import 'scheduling_screen.dart';
import 'transactions_screen.dart';
import 'payroll_screen.dart';
import 'analytics_screen.dart';

class AdminStaffHome extends StatefulWidget {
  const AdminStaffHome({super.key});

  @override
  State<AdminStaffHome> createState() => _AdminStaffHomeState();
}

class _AdminStaffHomeState extends State<AdminStaffHome> {
  int _selectedIndex = 0;
  List<InventoryItem> _lowStockItems = [];

  // Dashboard data
  bool _isDashboardLoading = true;
  double _todayRevenue = 0.0;
  double _totalRevenue = 0.0;
  double _todayExpenses = 0.0;
  int _pendingBookings = 0;
  List<Map<String, dynamic>> _recentTransactions = [];
  List<Map<String, dynamic>> _pendingBookingsList = [];

  @override
  void initState() {
    super.initState();
    _loadLowStockItems();
    _loadDashboardData();
  }

  Future<void> _loadLowStockItems() async {
    try {
      final items = await InventoryManager.getLowStockItems();
      if (mounted) {
        setState(() {
          _lowStockItems = items;
        });
      }
    } catch (e) {
      // Handle error silently for now
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isDashboardLoading = true);

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      // Load today's transactions
      final transactionsSnapshot = await FirebaseFirestore.instance
          .collection('Transactions')
          .where('transactionAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('transactionAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('transactionAt', descending: true)
          .limit(5)
          .get();

      double todayRev = 0.0;
      List<Map<String, dynamic>> recentTxns = [];

      for (final doc in transactionsSnapshot.docs) {
        final data = doc.data();
        todayRev += (data['total'] as num?)?.toDouble() ?? 0.0;
        recentTxns.add({
          'id': doc.id,
          'customer': data['customerName'] ?? 'Walk-in',
          'amount': (data['total'] as num?)?.toDouble() ?? 0.0,
          'time': (data['transactionAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        });
      }

      // Load all-time revenue
      final allTransactionsSnapshot = await FirebaseFirestore.instance
          .collection('Transactions')
          .get();

      double totalRev = 0.0;
      for (final doc in allTransactionsSnapshot.docs) {
        final data = doc.data();
        totalRev += (data['total'] as num?)?.toDouble() ?? 0.0;
      }

      // Load today's expenses
      final expensesSnapshot = await ExpenseManager.getExpenses(
        startDate: startOfDay,
        endDate: endOfDay,
      );

      double todayExp = expensesSnapshot.fold(0.0, (sum, expense) => sum + expense.amount);

      // Load today's approved bookings from scheduling (not completed)
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('Bookings')
          .where('status', isEqualTo: 'approved')
          .get();

      List<Map<String, dynamic>> pendingBookings = [];
      for (final doc in bookingsSnapshot.docs) {
        final data = doc.data();
        // Use unified scheduledDateTime field (with fallback for legacy data)
        final scheduledDate = (data['scheduledDateTime'] as Timestamp?)?.toDate() ??
                             (data['selectedDateTime'] as Timestamp?)?.toDate() ??
                             (data['scheduledDate'] as Timestamp?)?.toDate();

        // Only include today's bookings
        if (scheduledDate != null &&
            scheduledDate.year == today.year &&
            scheduledDate.month == today.month &&
            scheduledDate.day == today.day) {

          final services = data['services'] as List?;
          final serviceNames = services?.map((s) => s['serviceName'] ?? '').join(', ') ?? 'No services';

          pendingBookings.add({
            'id': doc.id,
            'plateNumber': data['plateNumber'] ?? data['vehiclePlateNumber'] ?? 'No Plate',
            'services': serviceNames,
            'scheduledDate': scheduledDate,
          });
        }
      }

      if (mounted) {
        setState(() {
          _todayRevenue = todayRev;
          _totalRevenue = totalRev;
          _todayExpenses = todayExp;
          _pendingBookings = pendingBookings.length;
          _pendingBookingsList = pendingBookings;
          _recentTransactions = recentTxns;
          _isDashboardLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDashboardLoading = false);
      }
    }
  }

  /// Define menu items
  List<String> getMenuItems() {
    final items = <String>[
      "Dashboard",
      "POS",
      "Transactions",
      "Inventory",
      "Expenses",
      "Services",
      "Scheduling",
      "Payroll",
      "Analytics",
    ];
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final menuItems = getMenuItems();
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1a1a1a),
                Colors.black,
                const Color(0xFF333333),
              ],
            ),
            boxShadow: isDesktop ? [
              BoxShadow(
                color: Colors.yellow.shade700.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 1),
              ),
            ] : [
              BoxShadow(
                color: Colors.yellow.shade700.withValues(alpha: 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: AppBar(
            title: Text(
              menuItems[_selectedIndex],
              style: TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w700,
                fontSize: isDesktop ? 26 : 22,
                color: Colors.yellow[700],
                letterSpacing: 0.5,
              ),
            ),
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.yellow[700],
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            iconTheme: IconThemeData(
              color: Colors.yellow[700],
              size: 28,
            ),
          ),
        ),
      ),
      drawer: isDesktop ? null : _buildDrawer(menuItems),
      body: isDesktop
          ? Stack(
              children: [
                // Sidebar that extends full height
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: _buildSideNav(menuItems),
                ),
                // Main content with left margin
                Positioned(
                  left: 280,
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.white,
                    child: _buildPage(menuItems[_selectedIndex]),
                  ),
                ),
              ],
            )
          : Container(
              color: Colors.white,
              child: _buildPage(menuItems[_selectedIndex]),
            ),
      floatingActionButton: _selectedIndex == 3 // Inventory
          ? FloatingActionButton.extended(
              onPressed: () => _showAddItemDialog(),
              backgroundColor: Colors.yellow.shade700,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: const Text("Add Item", style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : _selectedIndex == 4 // Expenses
              ? null // FAB is in ExpensesScreen itself
              : _selectedIndex == 5 // Services
                  ? FloatingActionButton.extended(
                      onPressed: () => _showAddServiceDialog(),
                      backgroundColor: Colors.yellow.shade700,
                      foregroundColor: Colors.black,
                      icon: const Icon(Icons.add),
                      label: const Text("Add Service", style: TextStyle(fontWeight: FontWeight.w600)),
                    )
                  : null,
    );
  }

  /// Drawer (Mobile)
  Widget _buildDrawer(List<String> menuItems) {
    final iconMap = {
      "Dashboard": Icons.dashboard_outlined,
      "POS": Icons.point_of_sale_outlined,
      "Transactions": Icons.receipt_long_outlined,
      "Inventory": Icons.inventory_2_outlined,
      "Expenses": Icons.money_off_outlined,
      "Services": Icons.build_outlined,
      "Scheduling": Icons.calendar_today_outlined,
      "Payroll": Icons.payment_outlined,
      "Analytics": Icons.show_chart_outlined,
    };

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1a1a1a),
                  Colors.black,
                  const Color(0xFF333333),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.yellow.shade700.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.local_car_wash,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "EC Carwash",
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.yellow.shade700,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final title = menuItems[index];
                final isSelected = _selectedIndex == index;
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() => _selectedIndex = index);
                        Navigator.pop(context);
                        if (index == 0) {
                          _loadDashboardData();
                          _loadLowStockItems();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.yellow.shade700
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              iconMap[title] ?? Icons.circle_outlined,
                              color: isSelected
                                  ? Colors.black
                                  : Colors.grey.shade400,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              title,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                color: isSelected
                                    ? Colors.black
                                    : Colors.grey.shade300,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 15,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Side Nav (Desktop/Web)
  Widget _buildSideNav(List<String> menuItems) {
    final iconMap = {
      "Dashboard": Icons.dashboard_outlined,
      "POS": Icons.point_of_sale_outlined,
      "Transactions": Icons.receipt_long_outlined,
      "Inventory": Icons.inventory_2_outlined,
      "Expenses": Icons.money_off_outlined,
      "Services": Icons.build_outlined,
      "Scheduling": Icons.calendar_today_outlined,
      "Payroll": Icons.payment_outlined,
      "Analytics": Icons.show_chart_outlined,
    };

    final selectedIconMap = {
      "Dashboard": Icons.dashboard,
      "POS": Icons.point_of_sale,
      "Transactions": Icons.receipt_long,
      "Inventory": Icons.inventory_2,
      "Expenses": Icons.money_off,
      "Services": Icons.build,
      "Scheduling": Icons.calendar_today,
      "Payroll": Icons.payment,
      "Analytics": Icons.show_chart,
    };

    return Container(
      width: 280,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1a1a1a),
            Colors.black,
            const Color(0xFF333333),
            Colors.grey.shade900,
          ],
        ),
        border: Border(
          right: BorderSide(
            color: Colors.yellow.shade700.withValues(alpha: 0.4),
            width: 3,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.yellow.shade700.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(2, 0),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(1, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_car_wash,
                    color: Colors.black,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "EC Carwash",
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.yellow.shade700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final title = menuItems[index];
                final isSelected = _selectedIndex == index;
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() => _selectedIndex = index);
                        if (index == 0) {
                          _loadDashboardData();
                          _loadLowStockItems();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.yellow.shade700
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? selectedIconMap[title] ?? Icons.circle
                                  : iconMap[title] ?? Icons.circle_outlined,
                              color: isSelected
                                  ? Colors.black
                                  : Colors.grey.shade400,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              title,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                color: isSelected
                                    ? Colors.black
                                    : Colors.grey.shade300,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 15,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Page Content Switch
  Widget _buildPage(String menu) {
    switch (menu) {
      case "Dashboard":
        return _buildDashboard();
      case "POS":
        return const POSScreen();
      case "Transactions":
        return const TransactionsScreen();
      case "Inventory":
        return const InventoryScreen();
      case "Expenses":
        return const ExpensesScreen();
      case "Services":
        return const ServicesScreen();
      case "Scheduling":
        return const SchedulingScreen();
      case "Payroll":
        return const PayrollScreen();
      case "Analytics":
        return const AnalyticsScreen();
      default:
        return Center(
          child: Text(
            "Page: $menu",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        );
    }
  }

  void _showAddItemDialog() async {
    // Load existing items to check for duplicates
    final existingItems = await InventoryManager.getItems();
    final existingNames = existingItems.map((item) => item.name.toLowerCase()).toSet();

    if (!mounted) return;

    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final stockController = TextEditingController();
    final minStockController = TextEditingController();
    final priceController = TextEditingController();
    final unitController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add New Inventory Item'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Item Name *',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Car Shampoo',
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Item name is required';
                    }
                    if (existingNames.contains(value.trim().toLowerCase())) {
                      return 'Item already exists! Use stock adjustment instead.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Cleaning Supplies',
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Category is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: stockController,
                        decoration: const InputDecoration(
                          labelText: 'Initial Stock *',
                          border: OutlineInputBorder(),
                          hintText: '0',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final stock = int.tryParse(value);
                          if (stock == null || stock < 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: minStockController,
                        decoration: const InputDecoration(
                          labelText: 'Min Stock *',
                          border: OutlineInputBorder(),
                          hintText: '10',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final stock = int.tryParse(value);
                          if (stock == null || stock < 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: priceController,
                        decoration: const InputDecoration(
                          labelText: 'Unit Price (₱) *',
                          border: OutlineInputBorder(),
                          hintText: '0.00',
                          prefixText: '₱ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final price = double.tryParse(value);
                          if (price == null || price < 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: unitController,
                        decoration: const InputDecoration(
                          labelText: 'Unit *',
                          border: OutlineInputBorder(),
                          hintText: 'bottles',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  final newItem = InventoryItem(
                    id: '',
                    name: nameController.text.trim(),
                    category: categoryController.text.trim(),
                    currentStock: int.parse(stockController.text),
                    minStock: int.parse(minStockController.text),
                    unitPrice: double.parse(priceController.text),
                    unit: unitController.text.trim(),
                    lastUpdated: DateTime.now(),
                  );

                  await InventoryManager.addItem(newItem);
                  await _loadLowStockItems();

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text('${newItem.name} added successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow.shade700,
              foregroundColor: Colors.black,
            ),
            child: const Text('Add Item'),
          ),
        ],
      ),
    );
  }

  void _showAddServiceDialog() {
    // Navigate to services screen will show the add dialog
    // The actual dialog is in services_screen.dart
    // For now, just show a message to use the + button in services tab
    if (_selectedIndex != 4) {
      setState(() => _selectedIndex = 4);
    }

    // Give time for navigation then trigger dialog in services screen
    Future.delayed(const Duration(milliseconds: 300), () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please use the menu options to add a service'),
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

  /// World-Class Professional Dashboard with Yellow/Black Theme
  Widget _buildDashboard() {
    if (_isDashboardLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Net Profit Card at Top
          _buildNetProfitCard(),

          const SizedBox(height: 20),

          // KPI Cards - 3 cards in a row
          Row(
            children: [
              Expanded(
                child: _buildKPICard(
                  title: 'Total Revenue',
                  value: '₱${_totalRevenue.toStringAsFixed(2)}',
                  icon: Icons.account_balance_wallet,
                  subtitle: 'All time',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKPICard(
                  title: "Today's Expenses",
                  value: '₱${_todayExpenses.toStringAsFixed(2)}',
                  icon: Icons.money_off,
                  subtitle: 'Operating costs',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKPICard(
                  title: 'Pending Bookings',
                  value: '$_pendingBookings',
                  icon: Icons.schedule,
                  subtitle: 'Awaiting service',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Recent Activity Section - 3 cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 1200;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildRecentTransactionsCard()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildPendingServicesCard()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildLowStockCard()),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildRecentTransactionsCard(),
                    const SizedBox(height: 16),
                    _buildPendingServicesCard(),
                    const SizedBox(height: 16),
                    _buildLowStockCard(),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  /// KPI Card - Yellow/Black Theme
  Widget _buildKPICard({
    required String title,
    required String value,
    required IconData icon,
    required String subtitle,
  }) {
    return Card(
      color: Colors.yellow.shade50,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black87, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade700,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black87, width: 1),
                  ),
                  child: Icon(icon, color: Colors.black87, size: 24),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black.withValues(alpha: 0.7),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Net Profit Card
  Widget _buildNetProfitCard() {
    final netProfit = _todayRevenue - _todayExpenses;
    final isPositive = netProfit >= 0;

    return Card(
      color: Colors.yellow.shade700,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black87, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                color: Colors.yellow.shade700,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Net Profit",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₱${netProfit.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Revenue: ₱${_todayRevenue.toStringAsFixed(2)} - Expenses: ₱${_todayExpenses.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Recent Transactions Card
  Widget _buildRecentTransactionsCard() {
    return Card(
      color: Colors.yellow.shade50,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black87, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.black87, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Recent Transactions',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1.5, color: Colors.black87),
          _recentTransactions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No transactions today',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentTransactions.length > 5 ? 5 : _recentTransactions.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                  itemBuilder: (context, index) {
                    final txn = _recentTransactions[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.yellow.shade700,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black87, width: 1),
                        ),
                        child: const Icon(Icons.shopping_cart, color: Colors.black87, size: 20),
                      ),
                      title: Text(
                        txn['customer'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        DateFormat('HH:mm').format(txn['time']),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black.withValues(alpha: 0.6),
                        ),
                      ),
                      trailing: Text(
                        '₱${txn['amount'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  /// Pending Services Card
  Widget _buildPendingServicesCard() {
    return Card(
      color: Colors.yellow.shade50,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black87, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.build_circle, color: Colors.black87, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Pending Services',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade700,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black87, width: 1),
                  ),
                  child: Text(
                    '$_pendingBookings',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1.5, color: Colors.black87),
          _pendingBookingsList.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No upcoming bookings',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _pendingBookingsList.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.black87),
                  itemBuilder: (context, index) {
                    final booking = _pendingBookingsList[index];
                    final scheduledDate = booking['scheduledDate'] as DateTime?;
                    final plateNumber = booking['plateNumber'] as String;
                    final services = booking['services'] as String;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.yellow.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black87, width: 1),
                        ),
                        child: const Icon(Icons.directions_car, color: Colors.black87, size: 20),
                      ),
                      title: Text(
                        plateNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        services,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: scheduledDate != null
                          ? Text(
                              DateFormat('hh:mm a').format(scheduledDate),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            )
                          : null,
                    );
                  },
                ),
        ],
      ),
    );
  }

  /// Low Stock Alert Card
  Widget _buildLowStockCard() {
    return Card(
      color: Colors.yellow.shade50,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black87, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.black87, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Low Stock Alerts',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade700,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black87, width: 1),
                  ),
                  child: Text(
                    '${_lowStockItems.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1.5, color: Colors.black87),
          _lowStockItems.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'All items in stock',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _lowStockItems.length > 5 ? 5 : _lowStockItems.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                  itemBuilder: (context, index) {
                    final item = _lowStockItems[index];
                    final isCritical = item.currentStock <= item.minStock / 2;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isCritical ? Colors.red.shade100 : Colors.yellow.shade700,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCritical ? Colors.red.shade700 : Colors.black87,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          isCritical ? Icons.error : Icons.inventory_2,
                          color: isCritical ? Colors.red.shade700 : Colors.black87,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        'Min: ${item.minStock} ${item.unit}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black.withValues(alpha: 0.6),
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCritical ? Colors.red.shade100 : Colors.yellow.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isCritical ? Colors.red.shade700 : Colors.black87,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${item.currentStock} ${item.unit}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isCritical ? Colors.red.shade700 : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
