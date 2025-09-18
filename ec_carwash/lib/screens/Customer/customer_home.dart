import 'package:flutter/material.dart';
import 'book_service_screen.dart'; // ⬅️ Import your booking screen

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  // Track the selected menu item
  String _selectedMenu = "Home";

  void _onSelect(String menu) {
    setState(() {
      _selectedMenu = menu;
    });
    Navigator.pop(context); // Close the drawer

    // Navigate based on menu selection
    if (menu == "Book") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BookServiceScreen()),
      );
    }
    // You can add more navigation conditions here for "History", etc.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Customer Dashboard")),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.yellow[700]),
              child: const Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  "EC Carwash",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Home
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text("Home"),
              selected: _selectedMenu == "Home",
              selectedTileColor: Colors.yellow[100],
              onTap: () => _onSelect("Home"),
            ),

            // Book a Service
            ListTile(
              leading: const Icon(Icons.book_online),
              title: const Text("Book a Service"),
              selected: _selectedMenu == "Book",
              selectedTileColor: Colors.yellow[100],
              onTap: () => _onSelect("Book"),
            ),

            // Booking History
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text("Booking History"),
              selected: _selectedMenu == "History",
              selectedTileColor: Colors.yellow[100],
              onTap: () => _onSelect("History"),
            ),

            const Divider(),

            // Logout
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: () {
                // TODO: implement logout logic
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),

      body: Center(
        child: Text(
          "Current Page: $_selectedMenu",
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
