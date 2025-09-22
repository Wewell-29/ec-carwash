import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'book_service_screen.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  String _selectedMenu = "Home";

  void _onSelect(String menu) {
    setState(() {
      _selectedMenu = menu;
    });
    Navigator.pop(context); // Close the drawer

    if (menu == "Book") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BookServiceScreen()),
      );
    }
    // Add more navigation options for History, etc.
  }

  String _formatDateTime(dynamic rawDate, dynamic rawTime) {
    try {
      if (rawDate == null) return "N/A";

      DateTime dateTime;

      // If Firestore Timestamp
      if (rawDate is Timestamp) {
        dateTime = rawDate.toDate();
      }
      // If already DateTime
      else if (rawDate is DateTime) {
        dateTime = rawDate;
      }
      // If saved as String
      else {
        dateTime = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
      }

      // If separate time exists (string like "14:30")
      if (rawTime != null && rawTime.toString().isNotEmpty) {
        final timeParts = rawTime.toString().split(":");
        if (timeParts.length >= 2) {
          dateTime = DateTime(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            int.tryParse(timeParts[0]) ?? dateTime.hour,
            int.tryParse(timeParts[1]) ?? dateTime.minute,
          );
        }
      }

      return DateFormat('MMM dd, yyyy – hh:mm a').format(dateTime);
    } catch (e) {
      return rawDate.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text("Home"),
              selected: _selectedMenu == "Home",
              selectedTileColor: Colors.yellow[100],
              onTap: () => _onSelect("Home"),
            ),
            ListTile(
              leading: const Icon(Icons.book_online),
              title: const Text("Book a Service"),
              selected: _selectedMenu == "Book",
              selectedTileColor: Colors.yellow[100],
              onTap: () => _onSelect("Book"),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text("Booking History"),
              selected: _selectedMenu == "History",
              selectedTileColor: Colors.yellow[100],
              onTap: () => _onSelect("History"),
            ),
            const Divider(),
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
      body: user == null
          ? const Center(child: Text("Please log in to see your bookings."))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("Bookings")
                  .where("userEmail", isEqualTo: user.email)
                  .orderBy("createdAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("No ongoing bookings found."),
                  );
                }

                final bookings = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking =
                        bookings[index].data() as Map<String, dynamic>;

                    final services =
                        booking["services"] as List<dynamic>? ?? [];
                    final plate = booking["plateNumber"] ?? "N/A";
                    final date = booking["date"];
                    final time = booking["time"];

                    final formattedDateTime = _formatDateTime(date, time);

                    return Card(
                      margin: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      child: ListTile(
                        title: Text("Plate: $plate"),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Date: $formattedDateTime"),
                            const SizedBox(height: 4),
                            Text(
                              "Services: " +
                                  (services.isNotEmpty
                                      ? services
                                            .map(
                                              (s) =>
                                                  (s
                                                      as Map<
                                                        String,
                                                        dynamic
                                                      >)["serviceName"] ??
                                                  "",
                                            )
                                            .join(", ")
                                      : "N/A"),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
