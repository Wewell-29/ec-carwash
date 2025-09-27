import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Navigate to these
import 'book_service_screen.dart';
import 'customer_home.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  String _selectedMenu = "History";

  void _onSelect(String menu) {
    setState(() => _selectedMenu = menu);
    Navigator.pop(context); // close drawer first

    if (menu == "Home") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CustomerHome()),
      );
    } else if (menu == "Book") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BookServiceScreen()),
      );
    } else if (menu == "History") {
      // already here — optional: do nothing
    }
  }

  String _formatDateTime(dynamic rawDate, dynamic rawTime) {
    try {
      if (rawDate == null) return "N/A";
      DateTime dt;

      if (rawDate is Timestamp) {
        dt = rawDate.toDate();
      } else if (rawDate is DateTime) {
        dt = rawDate;
      } else {
        dt = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
      }

      if (rawTime != null && rawTime.toString().isNotEmpty) {
        // supports either "14:30" or maps like {hour: 14, minute: 30, formatted: "2:30 PM"}
        if (rawTime is Map &&
            rawTime['hour'] != null &&
            rawTime['minute'] != null) {
          dt = DateTime(
            dt.year,
            dt.month,
            dt.day,
            rawTime['hour'],
            rawTime['minute'],
          );
        } else {
          final parts = rawTime.toString().split(':');
          if (parts.length >= 2) {
            dt = DateTime(
              dt.year,
              dt.month,
              dt.day,
              int.tryParse(parts[0]) ?? dt.hour,
              int.tryParse(parts[1]) ?? dt.minute,
            );
          }
        }
      }

      return DateFormat('MMM dd, yyyy – hh:mm a').format(dt);
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
          title: const Text('Booking History'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),

        // Drawer copied to match CustomerHome style
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
                onTap: () => Navigator.pop(context), // TODO: add logout logic
              ),
            ],
          ),
        ),

        body: user == null
            ? const Center(child: Text('Please log in to view history.'))
            : TabBarView(
                children: [
                  _buildCompletedTab(user), // from Transactions
                  _buildCancelledTab(
                    user,
                  ), // from Bookings(status == cancelled)
                ],
              ),
      ),
    );
  }

  /// COMPLETED = from Transactions where customer.email == user.email
  Widget _buildCompletedTab(User user) {
    final stream = FirebaseFirestore.instance
        .collection('Transactions')
        .where('customer.email', isEqualTo: user.email)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(child: Text('No completed transactions.'));
        }

        final docs = snap.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final customer = (data['customer'] as Map<String, dynamic>?) ?? {};
            final plate = (customer['plateNumber'] ?? 'N/A').toString();

            final date = data['transactionAt'] ?? data['createdAt'];
            final time = data['time']; // may be {hour, minute, formatted}
            final formattedDateTime = _formatDateTime(date, time);

            final items = (data['items'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>();
            final total = (data['total'] ?? 0).toString();

            return Card(
              margin: const EdgeInsets.all(12),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: Text('Plate: $plate'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date: $formattedDateTime'),
                    const SizedBox(height: 4),
                    Text(
                      items.isNotEmpty
                          ? 'Items: ${items.map((e) => '${e['code']} (${e['vehicleType']})').join(', ')}'
                          : 'Items: N/A',
                    ),
                    const SizedBox(height: 4),
                    Text('Total: ₱$total'),
                  ],
                ),
                trailing: const Chip(
                  label: Text(
                    'COMPLETED',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: Colors.green,
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// CANCELLED = from Bookings where userEmail == user.email AND status == "cancelled"
  Widget _buildCancelledTab(User user) {
    final stream = FirebaseFirestore.instance
        .collection('Bookings')
        .where('userEmail', isEqualTo: user.email)
        .where('status', isEqualTo: 'cancelled')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(child: Text('No cancelled bookings.'));
        }

        final docs = snap.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final plate = (data['plateNumber'] ?? 'N/A').toString();

            final date = data['selectedDateTime'] ?? data['date'];
            final time = data['time'];
            final formattedDateTime = _formatDateTime(date, time);

            final services = (data['services'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>();
            final total = data['total']; // if you saved it on the booking

            return Card(
              margin: const EdgeInsets.all(12),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: Text('Plate: $plate'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date: $formattedDateTime'),
                    const SizedBox(height: 4),
                    Text(
                      services.isNotEmpty
                          ? 'Services: ${services.map((s) => s['serviceName'] ?? '').join(', ')}'
                          : 'Services: N/A',
                    ),
                    if (total != null) ...[
                      const SizedBox(height: 4),
                      Text('Total: ₱$total'),
                    ],
                  ],
                ),
                trailing: const Chip(
                  label: Text(
                    'CANCELLED',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: Colors.redAccent,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
