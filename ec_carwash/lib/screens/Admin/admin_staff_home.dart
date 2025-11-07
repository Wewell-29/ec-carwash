import 'package:flutter/material.dart';
import 'package:ec_carwash/data_models/inventory_data.dart';
import 'package:ec_carwash/data_models/expense_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ec_carwash/utils/responsive_helper.dart';
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
  VoidCallback? _showAddServiceDialogCallback;
  List<InventoryItem> _lowStockItems = [];

  // Dashboard data
  bool _isDashboardLoading = true;
  double _todayRevenue = 0.0;
  double _totalRevenue = 0.0;
  double _todayExpenses = 0.0;
  double _todayPayrollCommission = 0.0;
  int _pendingBookings = 0;
  List<Map<String, dynamic>> _recentTransactions = [];
  List<Map<String, dynamic>> _approvedBookingsList = [];

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
      return;
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isDashboardLoading = true);

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final allTodayTransactionsSnapshot = await FirebaseFirestore.instance
          .collection('Transactions')
          .where('transactionAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('transactionAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('transactionAt', descending: true)
          .get();

      double todayRev = 0.0;
      double todayCommission = 0.0;
      List<Map<String, dynamic>> recentTxns = [];

      for (int i = 0; i < allTodayTransactionsSnapshot.docs.length; i++) {
        final doc = allTodayTransactionsSnapshot.docs[i];
        final data = doc.data();
        todayRev += (data['total'] as num?)?.toDouble() ?? 0.0;
        todayCommission += (data['teamCommission'] as num?)?.toDouble() ?? 0.0;

        if (i < 5) {
          final customerData = data['customer'] as Map<String, dynamic>?;
          final customerName = customerData?['name'] ?? 'Walk-in';

          recentTxns.add({
            'id': doc.id,
            'customer': customerName,
            'amount': (data['total'] as num?)?.toDouble() ?? 0.0,
            'time': (data['transactionAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          });
        }
      }

      final allTransactionsSnapshot = await FirebaseFirestore.instance
          .collection('Transactions')
          .get();

      double totalRev = 0.0;
      for (final doc in allTransactionsSnapshot.docs) {
        final data = doc.data();
        totalRev += (data['total'] as num?)?.toDouble() ?? 0.0;
      }

      final expensesSnapshot = await ExpenseManager.getExpenses(
        startDate: startOfDay,
        endDate: endOfDay,
      );

      double todayExp = expensesSnapshot.fold(0.0, (total, expense) => total + expense.amount);

      final pendingBookingsSnapshot = await FirebaseFirestore.instance
          .collection('Bookings')
          .where('status', isEqualTo: 'pending')
          .get();

      List<Map<String, dynamic>> pendingBookings = [];
      for (final doc in pendingBookingsSnapshot.docs) {
        final data = doc.data();
        final scheduledDate = (data['scheduledDateTime'] as Timestamp?)?.toDate() ??
                             (data['selectedDateTime'] as Timestamp?)?.toDate() ??
                             (data['scheduledDate'] as Timestamp?)?.toDate();

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

      final approvedBookingsSnapshot = await FirebaseFirestore.instance
          .collection('Bookings')
          .where('status', isEqualTo: 'approved')
          .get();

      List<Map<String, dynamic>> approvedBookings = [];
      for (final doc in approvedBookingsSnapshot.docs) {
        final data = doc.data();
        final scheduledDate = (data['scheduledDateTime'] as Timestamp?)?.toDate() ??
                             (data['selectedDateTime'] as Timestamp?)?.toDate() ??
                             (data['scheduledDate'] as Timestamp?)?.toDate();

        if (scheduledDate != null &&
            scheduledDate.year == today.year &&
            scheduledDate.month == today.month &&
            scheduledDate.day == today.day) {

          final services = data['services'] as List?;
          final serviceNames = services?.map((s) => s['serviceName'] ?? '').join(', ') ?? 'No services';

          approvedBookings.add({
            'id': doc.id,
            'plateNumber': data['plateNumber'] ?? data['vehiclePlateNumber'] ?? 'No Plate',
            'services': serviceNames,
            'scheduledDate': scheduledDate,
          });
        }
      }

      if (approvedBookings.length > 5) {
        approvedBookings = approvedBookings.sublist(0, 5);
      }

      pendingBookings.sort((a, b) {
        final dateA = a['scheduledDate'] as DateTime?;
        final dateB = b['scheduledDate'] as DateTime?;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      });

      approvedBookings.sort((a, b) {
        final dateA = a['scheduledDate'] as DateTime?;
        final dateB = b['scheduledDate'] as DateTime?;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      });

      if (mounted) {
        setState(() {
          _todayRevenue = todayRev;
          _totalRevenue = totalRev;
          _todayExpenses = todayExp;
          _todayPayrollCommission = todayCommission;
          _pendingBookings = pendingBookings.length;
          _approvedBookingsList = approvedBookings;
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
    final responsive = context.responsive;
    final isDesktop = responsive.isDesktop;

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
                fontSize: responsive.fontSize(mobile: 20, tablet: 22, desktop: 26),
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
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: _buildSideNav(menuItems, responsive),
                ),
                Positioned(
                  left: responsive.sidebarWidth,
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
      floatingActionButton: _selectedIndex == 3
          ? FloatingActionButton.extended(
              onPressed: () => _showAddItemDialog(),
              backgroundColor: Colors.yellow.shade700,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: const Text("Add Item", style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : _selectedIndex == 4
              ? null
              : _selectedIndex == 5
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
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  iconMap[title] ?? Icons.circle_outlined,
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.grey.shade400,
                                  size: 22,
                                ),
                                // Red dot indicator for pending bookings on Scheduling
                                if (title == "Scheduling" && _pendingBookings > 0)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
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
                            // Badge with count for pending bookings
                            if (title == "Scheduling" && _pendingBookings > 0) ...[
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _pendingBookings.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
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

  Widget _buildSideNav(List<String> menuItems, ResponsiveHelper responsive) {
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

    final isCompact = responsive.useNavigationRail;

    return Container(
      width: responsive.sidebarWidth,
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
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 20),
            child: isCompact
                ? Center(
                    child: Container(
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
                  )
                : Row(
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
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 8 : 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.yellow.shade700
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: isCompact
                            ? Center(
                                child: Stack(
                                  clipBehavior: Clip.none,
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
                                    if (title == "Scheduling" && _pendingBookings > 0)
                                      Positioned(
                                        right: -2,
                                        top: -2,
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            : // Full mode - icon + text
                            Row(
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
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
                                      if (title == "Scheduling" && _pendingBookings > 0)
                                        Positioned(
                                          right: -2,
                                          top: -2,
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
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
                                  if (title == "Scheduling" && _pendingBookings > 0) ...[
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _pendingBookings.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
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
        return ServicesScreen(
          onShowAddDialog: (callback) {
            _showAddServiceDialogCallback = callback;
          },
        );
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
    if (_selectedIndex != 5) {
      setState(() => _selectedIndex = 5);

      Future.delayed(const Duration(milliseconds: 500), () {
        if (_showAddServiceDialogCallback != null) {
          _showAddServiceDialogCallback!();
        }
      });
    } else {
      if (_showAddServiceDialogCallback != null) {
        _showAddServiceDialogCallback!();
      }
    }
  }

  Widget _buildDashboard() {
    if (_isDashboardLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final responsive = context.responsive;

        return SingleChildScrollView(
          padding: responsive.dashboardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNetProfitCard(responsive),

              SizedBox(height: responsive.sectionSpacing),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: responsive.kpiCardColumns,
                childAspectRatio: responsive.kpiCardAspectRatio,
                crossAxisSpacing: responsive.cardSpacing,
                mainAxisSpacing: responsive.cardSpacing,
                children: [
                  _buildKPICard(
                    title: 'Total Revenue',
                    value: '₱${_totalRevenue.toStringAsFixed(2)}',
                    icon: Icons.account_balance_wallet,
                    subtitle: 'All time',
                    responsive: responsive,
                  ),
                  _buildKPICard(
                    title: "Today's Expenses",
                    value: '₱${_todayExpenses.toStringAsFixed(2)}',
                    icon: Icons.money_off,
                    subtitle: 'Operating costs',
                    responsive: responsive,
                  ),
                  _buildKPICard(
                    title: 'Pending Bookings',
                    value: '$_pendingBookings',
                    icon: Icons.schedule,
                    subtitle: 'Awaiting service',
                    responsive: responsive,
                  ),
                ],
              ),

              SizedBox(height: responsive.sectionSpacing),

              _buildActivityCardsSection(responsive),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required IconData icon,
    required String subtitle,
    required ResponsiveHelper responsive,
  }) {
    return Card(
      color: Colors.yellow.shade50,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black87, width: 1.5),
      ),
      clipBehavior: Clip.hardEdge,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: responsive.responsiveValue(
                    mobile: const EdgeInsets.all(10),
                    tablet: const EdgeInsets.all(12),
                    desktop: const EdgeInsets.all(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(responsive.isMobile ? 6 : 8),
                            decoration: BoxDecoration(
                              color: Colors.yellow.shade700,
                              borderRadius: BorderRadius.circular(responsive.borderRadius),
                              border: Border.all(color: Colors.black87, width: 1),
                            ),
                            child: Icon(
                              icon,
                              color: Colors.black87,
                              size: responsive.isMobile ? 18 : 20,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                      SizedBox(height: responsive.isMobile ? 8 : 12),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: responsive.fontSize(mobile: 18, tablet: 20, desktop: 24),
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: responsive.fontSize(mobile: 11, tablet: 12, desktop: 13),
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: responsive.fontSize(mobile: 10, tablet: 10, desktop: 11),
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityCardsSection(ResponsiveHelper responsive) {
    if (responsive.activityCardColumns == 1) {
      return Column(
        children: [
          SizedBox(
            height: 500,
            child: _buildRecentTransactionsCard(responsive),
          ),
          SizedBox(height: responsive.cardSpacing),
          SizedBox(
            height: 500,
            child: _buildPendingServicesCard(responsive),
          ),
          SizedBox(height: responsive.cardSpacing),
          SizedBox(
            height: 500,
            child: _buildLowStockCard(responsive),
          ),
        ],
      );
    }

    if (responsive.activityCardColumns == 2) {
      return Column(
        children: [
          SizedBox(
            height: 500,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildRecentTransactionsCard(responsive)),
                SizedBox(width: responsive.cardSpacing),
                Expanded(child: _buildPendingServicesCard(responsive)),
              ],
            ),
          ),
          SizedBox(height: responsive.cardSpacing),
          SizedBox(
            height: 500,
            child: _buildLowStockCard(responsive),
          ),
        ],
      );
    }

    return SizedBox(
      height: 500,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildRecentTransactionsCard(responsive)),
          SizedBox(width: responsive.cardSpacing),
          Expanded(child: _buildPendingServicesCard(responsive)),
          SizedBox(width: responsive.cardSpacing),
          Expanded(child: _buildLowStockCard(responsive)),
        ],
      ),
    );
  }

  Widget _buildNetProfitCard(ResponsiveHelper responsive) {
    final netProfit = _todayRevenue - _todayExpenses - _todayPayrollCommission;
    final isPositive = netProfit >= 0;

    return Card(
      color: Colors.yellow.shade700,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black87, width: 2),
      ),
      child: Padding(
        padding: responsive.responsiveValue(
          mobile: const EdgeInsets.all(16),
          tablet: const EdgeInsets.all(20),
          desktop: const EdgeInsets.all(24),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(responsive.isMobile ? 10 : 14),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                color: Colors.yellow.shade700,
                size: responsive.iconSizeLarge,
              ),
            ),
            SizedBox(width: responsive.isMobile ? 12 : 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Net Profit",
                    style: TextStyle(
                      fontSize: responsive.fontSize(mobile: 14, tablet: 15, desktop: 16),
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '₱${netProfit.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: responsive.fontSize(mobile: 24, tablet: 28, desktop: 32),
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    'Revenue: ₱${_todayRevenue.toStringAsFixed(2)} - Expenses: ₱${_todayExpenses.toStringAsFixed(2)} - Payroll: ₱${_todayPayrollCommission.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: responsive.fontSize(mobile: 11, tablet: 12, desktop: 13),
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsCard(ResponsiveHelper responsive) {
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
          Expanded(
            child: _recentTransactions.isEmpty
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
          ),
        ],
      ),
    );
  }

  Widget _buildPendingServicesCard(ResponsiveHelper responsive) {
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
                    '${_approvedBookingsList.length}',
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
          Expanded(
            child: _approvedBookingsList.isEmpty
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
                    itemCount: _approvedBookingsList.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.black87),
                    itemBuilder: (context, index) {
                      final booking = _approvedBookingsList[index];
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
                ),
        ],
      ),
    );
  }

  Widget _buildLowStockCard(ResponsiveHelper responsive) {
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
          Expanded(
            child: _lowStockItems.isEmpty
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
                    itemCount: _lowStockItems.length,
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
          ),
        ],
      ),
    );
  }
}
