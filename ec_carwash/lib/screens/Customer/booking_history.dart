import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Navigate to these
import 'book_service_screen.dart';
import 'customer_home.dart';
import 'account_info_screen.dart';
import 'notifications_screen.dart';

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
    } else if (menu == "Notifications") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
    } else if (menu == "Account") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AccountInfoScreen()),
      );
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

  void _rebookTransaction(Map<String, dynamic> transactionData) {
    // Support both unified and legacy transaction shapes
    final legacyCustomer =
        (transactionData['customer'] as Map<String, dynamic>?) ?? {};
    final plateNumber = (transactionData['vehiclePlateNumber'] ??
            legacyCustomer['plateNumber'])
        ?.toString();

    // Get the services from the transaction (new: services, legacy: items)
    final rawList = (transactionData['services'] ?? transactionData['items'])
            as List<dynamic>? ??
        [];
    final services = rawList.cast<Map<String, dynamic>>();

    if (plateNumber == null || plateNumber.isEmpty || services.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Unable to rebook: Missing vehicle or service information'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Prepare a minimal customer object if legacy is missing
    final customer = legacyCustomer.isNotEmpty
        ? legacyCustomer
        : {
            'plateNumber': plateNumber,
            'name': transactionData['customerName'] ?? '',
          };

    // Navigate to the booking screen with the rebook data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookServiceScreen(
          rebookData: {
            'plateNumber': plateNumber,
            'services': services,
            'customer': customer,
          },
        ),
      ),
    );
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
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text("Notifications"),
                selected: _selectedMenu == "Notifications",
                selectedTileColor: Colors.yellow[100],
                onTap: () => _onSelect("Notifications"),
              ),
              ListTile(
                leading: const Icon(Icons.account_circle),
                title: const Text("Account"),
                selected: _selectedMenu == "Account",
                selectedTileColor: Colors.yellow[100],
                onTap: () => _onSelect("Account"),
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
    // Resolve the unified customerId for this user (new schema)
    final customerFuture = FirebaseFirestore.instance
        .collection('Customers')
        .where('email', isEqualTo: user.email)
        .limit(1)
        .get();

    return FutureBuilder<QuerySnapshot>(
      future: customerFuture,
      builder: (context, custSnap) {
        // While resolving the customer, show progress
        if (custSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Determine stream based on available schema
        Stream<QuerySnapshot> stream;
        if (custSnap.hasData && custSnap.data!.docs.isNotEmpty) {
          final customerId = custSnap.data!.docs.first.id;
          // New schema: filter by customerId
          stream = FirebaseFirestore.instance
              .collection('Transactions')
              .where('customerId', isEqualTo: customerId)
              .orderBy('transactionAt', descending: true)
              .snapshots();
        } else {
          // Legacy fallback: nested customer.email (may be absent in new data)
          stream = FirebaseFirestore.instance
              .collection('Transactions')
              .where('customer.email', isEqualTo: user.email)
              .orderBy('createdAt', descending: true)
              .snapshots();
        }

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

                // Plate number from unified field, fallback to legacy nested customer
                final legacyCustomer =
                    (data['customer'] as Map<String, dynamic>?) ?? {};
                final plate = (data['vehiclePlateNumber'] ??
                        legacyCustomer['plateNumber'] ??
                        'N/A')
                    .toString();

                // Use unified timestamp when available
                final scheduledDateTime =
                    data['transactionAt'] ?? data['createdAt'];
                final formattedDateTime =
                    _formatDateTime(scheduledDateTime);

                // Prefer new schema `services`, fallback to old `items`
                final rawList = (data['services'] ?? data['items'])
                        as List<dynamic>? ??
                    [];
                final entries = rawList.cast<Map<String, dynamic>>();

                // Build services label robustly
                final servicesLabel = entries.isNotEmpty
                    ? entries
                        .map((e) {
                          final code =
                              (e['serviceCode'] ?? e['code'] ?? '')
                                  .toString();
                          final name =
                              (e['serviceName'] ?? '').toString();
                          final vt =
                              (e['vehicleType'] ?? '').toString();
                          final title = name.isNotEmpty ? name : code;
                          return vt.isNotEmpty
                              ? '$title ($vt)'
                              : title;
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
                  child: Column(
                    children: [
                      ListTile(
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
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _rebookTransaction(data),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Rebook'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.yellow[700],
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
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
