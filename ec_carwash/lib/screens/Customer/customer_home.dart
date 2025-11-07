import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'book_service_screen.dart';
import 'booking_history.dart';
import 'reservation_detail_screen.dart';
import 'account_info_screen.dart';
import 'notifications_screen.dart';
import '../../services/fcm_token_manager.dart';
import '../../services/google_sign_in_service.dart';
import '../login_page.dart';

class CustomerHome extends StatefulWidget {
  final int initialTabIndex; // 0 = Pending, 1 = Approved

  const CustomerHome({super.key, this.initialTabIndex = 0});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  String _selectedMenu = "Home";

  @override
  void initState() {
    super.initState();
    // Ensure FCM token is saved/refreshed when customer opens the app
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      await FCMTokenManager.initializeToken();
    } catch (e) {
      // Silently fail - notification setup is not critical
      debugPrint('Failed to initialize notifications: $e');
    }
  }

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
    } else if (menu == "Notifications") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NotificationsScreen()),
      );
    } else if (menu == "Account") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AccountInfoScreen()),
      );
    }
  }

  String _formatDateTime(dynamic rawScheduledDateTime) {
    try {
      if (rawScheduledDateTime == null) return "N/A";

      DateTime dateTime;
      if (rawScheduledDateTime is Timestamp) {
        dateTime = rawScheduledDateTime.toDate();
      } else if (rawScheduledDateTime is DateTime) {
        dateTime = rawScheduledDateTime;
      } else {
        dateTime = DateTime.tryParse(rawScheduledDateTime.toString()) ?? DateTime.now();
      }

      return DateFormat('MMM dd, yyyy – hh:mm a').format(dateTime);
    } catch (_) {
      return rawScheduledDateTime.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: 2,
      initialIndex: (widget.initialTabIndex >= 0 && widget.initialTabIndex <= 1)
          ? widget.initialTabIndex
          : 0,
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
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await GoogleSignInService.signOut();
                    if (!mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false,
                    );
                  }
                },
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
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BookServiceScreen()),
            );
          },
          backgroundColor: Colors.yellow[700],
          foregroundColor: Colors.black,
          child: const Icon(Icons.add),
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

            // Use unified datetime field (with fallback for legacy data)
            final scheduledDateTime = booking["scheduledDateTime"] ??
                                     booking["selectedDateTime"] ??
                                     booking["date"];
            final formattedDateTime = _formatDateTime(scheduledDateTime);

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
                      services.isNotEmpty
                          ? "Services: ${services.map((s) => (s as Map<String, dynamic>)["serviceName"] ?? "").join(", ")}"
                          : "Services: N/A",
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
                onTap: () async {
                  if (status == 'pending') {
                    final docId = bookings[index].id;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReservationDetailScreen(
                          bookingId: docId,
                          initialData: booking,
                        ),
                      ),
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}
