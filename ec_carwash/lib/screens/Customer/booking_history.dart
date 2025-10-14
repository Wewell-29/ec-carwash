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
      // already here — do nothing
    }
  }

  String _formatDateTime(dynamic rawScheduledDateTime) {
    try {
      if (rawScheduledDateTime == null) return "N/A";

      DateTime dt;
      if (rawScheduledDateTime is Timestamp) {
        dt = rawScheduledDateTime.toDate();
      } else if (rawScheduledDateTime is DateTime) {
        dt = rawScheduledDateTime;
      } else {
        dt = DateTime.tryParse(rawScheduledDateTime.toString()) ?? DateTime.now();
      }

      return DateFormat('MMM dd, yyyy – hh:mm a').format(dt);
    } catch (_) {
      return rawScheduledDateTime.toString();
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

        // Drawer (matches CustomerHome style)
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
  /// Reads `services` first, falls back to legacy `items`.
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

            // Use unified datetime field (transactionAt is the timestamp)
            final scheduledDateTime = data['transactionAt'] ?? data['createdAt'];
            final formattedDateTime = _formatDateTime(scheduledDateTime);

            // Prefer new schema `services`, fallback to old `items`
            final rawList =
                (data['services'] ?? data['items']) as List<dynamic>? ?? [];
            final entries = rawList.cast<Map<String, dynamic>>();

            // Build services label robustly
            final servicesLabel = entries.isNotEmpty
                ? entries
                      .map((e) {
                        final code = (e['serviceCode'] ?? e['code'] ?? '')
                            .toString();
                        final name = (e['serviceName'] ?? '').toString();
                        final vt = (e['vehicleType'] ?? '').toString();
                        final title = name.isNotEmpty ? name : code;
                        return vt.isNotEmpty ? '$title ($vt)' : title;
                      })
                      .join(', ')
                : 'N/A';

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
                    Text('Services: $servicesLabel'),
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

            // Use unified datetime field (with fallback for legacy data)
            final scheduledDateTime = data['scheduledDateTime'] ??
                                     data['selectedDateTime'] ??
                                     data['date'];
            final formattedDateTime = _formatDateTime(scheduledDateTime);

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
