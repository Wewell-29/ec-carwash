import 'package:flutter/material.dart';
import 'package:ec_carwash/data_models/inventory_data.dart';
import 'pos_screen.dart';
import 'inventory_screen.dart';
import 'services_screen.dart';
import 'scheduling_screen.dart';

class AdminStaffHome extends StatefulWidget {
  const AdminStaffHome({super.key});

  @override
  State<AdminStaffHome> createState() => _AdminStaffHomeState();
}

class _AdminStaffHomeState extends State<AdminStaffHome> {
  int _selectedIndex = 0;
  List<InventoryItem> _lowStockItems = [];

  @override
  void initState() {
    super.initState();
    _loadLowStockItems();
  }

  Future<void> _loadLowStockItems() async {
    try {
      final items = await InventoryManager.getLowStockItems();
      setState(() {
        _lowStockItems = items;
      });
    } catch (e) {
      // Handle error silently for now
    }
  }

  /// Define menu items (Analytics only for Admin)
  List<String> getMenuItems() {
    final items = <String>[
      "Dashboard",
      "POS",
      "Transactions",
      "Inventory",
      "Expenses",
      "Services",
      "Scheduling",
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
              onPressed: () {
                // This will be handled by the inventory screen internally
              },
              backgroundColor: Colors.yellow.shade700,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: const Text("Add Item", style: TextStyle(fontWeight: FontWeight.w600)),
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
      "Analytics": Icons.analytics_outlined,
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
      "Analytics": Icons.analytics_outlined,
    };

    final selectedIconMap = {
      "Dashboard": Icons.dashboard,
      "POS": Icons.point_of_sale,
      "Transactions": Icons.receipt_long,
      "Inventory": Icons.inventory_2,
      "Expenses": Icons.money_off,
      "Services": Icons.build,
      "Scheduling": Icons.calendar_today,
      "Analytics": Icons.analytics,
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
                      onTap: () => setState(() => _selectedIndex = index),
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
      case "Inventory":
        return const InventoryScreen();
      case "Services":
        return const ServicesScreen();
      case "Scheduling":
        return const SchedulingScreen();
      default:
        return Center(
          child: Text(
            "Page: $menu",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        );
    }
  }

  /// Dashboard with KPIs + Tables (includes Low Stock Alerts)
  Widget _buildDashboard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1000; // desktop
        final isMedium = constraints.maxWidth > 700; // tablet

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              /// KPI Stat Cards
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildHighlightCard(
                    title: "Today’s Revenue",
                    value: "₱12,500",
                    icon: Icons.payments,
                    color: Colors.green,
                    width: isWide ? 300 : (isMedium ? 280 : double.infinity),
                  ),
                  _buildHighlightCard(
                    title: "Transactions",
                    value: "45",
                    icon: Icons.receipt_long,
                    color: Colors.blue,
                    width: isWide ? 300 : (isMedium ? 280 : double.infinity),
                  ),
                  _buildHighlightCard(
                    title: "Expenses",
                    value: "₱3,200",
                    icon: Icons.money_off,
                    color: Colors.red,
                    width: isWide ? 300 : (isMedium ? 280 : double.infinity),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              /// Table-like Cards (now includes Low Stock Alerts)
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildTableCard(
                    title: "Low Stock Items",
                    rows: _lowStockItems.map((item) =>
                      "${item.name} (${item.currentStock} ${item.unit})").toList(),
                    icon: Icons.warning,
                    iconColor: Colors.orange,
                    width: isWide ? 520 : (isMedium ? 480 : double.infinity),
                  ),
                  _buildTableCard(
                    title: "Pending Services",
                    rows: const [
                      "Car Wash - Honda Civic",
                      "Interior Cleaning - Toyota Vios",
                    ],
                    icon: Icons.schedule,
                    iconColor: Colors.blueGrey,
                    width: isWide ? 520 : (isMedium ? 480 : double.infinity),
                  ),
                  _buildTableCard(
                    title: "Recent Transactions",
                    rows: const [
                      "#1234 - ₱500",
                      "#1235 - ₱700",
                      "#1236 - ₱350",
                    ],
                    icon: Icons.attach_money,
                    iconColor: Colors.green,
                    width: isWide ? 520 : (isMedium ? 480 : double.infinity),
                  ),
                  _buildTableCard(
                    title: "Critical Stock Alerts",
                    rows: _lowStockItems.where((item) =>
                      item.currentStock <= item.minStock / 2).map((item) =>
                      "${item.name} critically low (${item.currentStock} ${item.unit})").toList(),
                    icon: Icons.error_outline,
                    iconColor: Colors.red,
                    width: isWide ? 520 : (isMedium ? 480 : double.infinity),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Highlight Stat Card (colored, responsive width)
  Widget _buildHighlightCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        color: color,
        elevation: 6,
        shadowColor: Colors.black38,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 16),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Table-like Card (with icons + responsive width)
  Widget _buildTableCard({
    required String title,
    required List<String> rows,
    required IconData icon,
    required Color iconColor,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 4,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            /// Rows
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: rows
                    .map(
                      (e) => Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(icon, size: 20, color: iconColor),
                          title: Text(e),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
