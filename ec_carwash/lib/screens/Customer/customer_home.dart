import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'book_service_screen.dart';
import 'booking_history.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  String _selectedMenu = "Home";

  void _onSelect(String menu) {
    setState(() => _selectedMenu = menu);
    Navigator.pop(context); // Close the drawer
    if (menu == "Book") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BookServiceScreen()),
      );
    } else if (menu == "History") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BookingHistoryScreen()),
      );
    }
  }

  String _formatDateTime(dynamic rawDate, dynamic rawTime) {
    try {
      if (rawDate == null) return "N/A";
      DateTime dateTime;

      if (rawDate is Timestamp) {
        dateTime = rawDate.toDate();
      } else if (rawDate is DateTime) {
        dateTime = rawDate;
      } else {
        dateTime = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
      }

      if (rawTime != null && rawTime.toString().isNotEmpty) {
        final parts = rawTime.toString().split(":");
        if (parts.length >= 2) {
          dateTime = DateTime(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            int.tryParse(parts[0]) ?? dateTime.hour,
            int.tryParse(parts[1]) ?? dateTime.minute,
          );
        }
      }
      return DateFormat('MMM dd, yyyy – hh:mm a').format(dateTime);
    } catch (_) {
      return rawDate.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Customer Dashboard"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Pending"),
              Tab(text: "Approved"),
            ],
          ),
        ),
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
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        body: user == null
            ? const Center(child: Text("Please log in to see your bookings."))
            : TabBarView(
                children: [
                  _buildBookingsList(user, "pending"),
                  _buildBookingsList(user, "approved"),
                ],
              ),
      ),
    );
  }

  /// Builds a list for the given status ("pending" or "approved")
  Widget _buildBookingsList(User user, String status) {
    final stream = FirebaseFirestore.instance
        .collection("Bookings")
        .where("userEmail", isEqualTo: user.email)
        .where("status", isEqualTo: status) // <-- filter by status
        .orderBy("createdAt", descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              status == "pending"
                  ? "No pending bookings."
                  : "No approved bookings.",
            ),
          );
        }

        final bookings = snapshot.data!.docs;

        return ListView.builder(
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index].data() as Map<String, dynamic>;
            final services = booking["services"] as List<dynamic>? ?? [];
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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      label: Text(
                        status.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: status == "approved"
                          ? Colors.green
                          : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
