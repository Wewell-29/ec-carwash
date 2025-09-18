import 'package:flutter/material.dart';
import 'pos_screen.dart';

class AdminStaffHome extends StatefulWidget {
  const AdminStaffHome({super.key});

  @override
  State<AdminStaffHome> createState() => _AdminStaffHomeState();
}

class _AdminStaffHomeState extends State<AdminStaffHome> {
  int _selectedIndex = 0;

  /// Define menu items (Analytics only for Admin)
  List<String> getMenuItems() {
    final items = <String>[
      "Dashboard",
      "POS",
      "Transactions",
      "Inventory",
      "Expenses",
      "Services",
      "Analytics",
    ];
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final menuItems = getMenuItems();
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: Text("Dashboard"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.yellow[700],
      ),
      drawer: isDesktop ? null : _buildDrawer(menuItems),
      body: Row(
        children: [
          if (isDesktop) _buildSideNav(menuItems),
          Expanded(child: _buildPage(menuItems[_selectedIndex])),
        ],
      ),
      // 🚫 Removed BottomNavigationBar
    );
  }

  /// Drawer (Mobile)
  Widget _buildDrawer(List<String> menuItems) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.black),
            child: Center(
              child: Text(
                "EC Carwash",
                style: TextStyle(
                  color: Colors.yellow[700],
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          ...menuItems.asMap().entries.map((entry) {
            final idx = entry.key;
            final title = entry.value;
            return ListTile(
              title: Text(title),
              selected: _selectedIndex == idx,
              onTap: () {
                setState(() => _selectedIndex = idx);
                Navigator.pop(context); // close drawer after selection
              },
            );
          }),
        ],
      ),
    );
  }

  /// Side Nav (Desktop/Web)
  Widget _buildSideNav(List<String> menuItems) {
    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      labelType: NavigationRailLabelType.all,
      backgroundColor: Colors.grey.shade100,
      selectedIconTheme: const IconThemeData(color: Colors.black),
      selectedLabelTextStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
      destinations: menuItems
          .map(
            (title) => NavigationRailDestination(
              icon: const Icon(Icons.circle_outlined),
              selectedIcon: const Icon(Icons.circle),
              label: Text(title),
            ),
          )
          .toList(),
    );
  }

  /// Page Content Switch
  Widget _buildPage(String menu) {
    switch (menu) {
      case "Dashboard":
        return _buildDashboard();
      case "POS":
        return const POSScreen(); // 👈 here
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
                    rows: const ["Shampoo", "Tire Cleaner"],
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
                    title: "Low Stock Alerts",
                    rows: const ["Wax below 10 units", "Soap almost out"],
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
