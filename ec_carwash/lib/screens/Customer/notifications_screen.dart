import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/google_sign_in_service.dart';
import '../login_page.dart';
import 'package:intl/intl.dart';
import 'package:ec_carwash/data_models/notification_data.dart';
import 'customer_home.dart';
import 'book_service_screen.dart';
import 'booking_history.dart';
import 'account_info_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _selectedMenu = "Notifications";
  bool _showUnreadOnly = false;

  void _navigateFromDrawer(String menu) {
    setState(() {
      _selectedMenu = menu;
    });
    Navigator.pop(context);

    if (menu == 'Home') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CustomerHome()),
      );
    } else if (menu == 'Book') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BookServiceScreen()),
      );
    } else if (menu == 'History') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BookingHistoryScreen()),
      );
    } else if (menu == 'Account') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AccountInfoScreen()),
      );
    } else if (menu == 'Notifications') {
      // Already in Notifications screen
    } else if (menu == 'Logout') {
      _handleLogout();
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await GoogleSignInService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  void _markAllAsRead() async {
    final user = _auth.currentUser;
    if (user?.email == null) return;

    try {
      await NotificationManager.markAllAsRead(user!.email!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteAllNotifications() async {
    final user = _auth.currentUser;
    if (user?.email == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Notifications'),
        content: const Text(
          'Are you sure you want to delete all notifications? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await NotificationManager.deleteAllNotifications(user!.email!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All notifications deleted'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'booking_approved':
        return Icons.check_circle;
      case 'booking_completed':
        return Icons.done_all;
      case 'booking_cancelled':
        return Icons.cancel;
      case 'reminder':
        return Icons.alarm;
      case 'promotion':
        return Icons.local_offer;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'booking_approved':
        return Colors.green;
      case 'booking_completed':
        return Colors.blue;
      case 'booking_cancelled':
        return Colors.red;
      case 'reminder':
        return Colors.orange;
      case 'promotion':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(dateTime);
    }
  }

  void _handleNotificationTap(NotificationData notification) async {
    // Mark as read
    if (!notification.isRead && notification.id != null) {
      await NotificationManager.markAsRead(notification.id!);
    }

    // Navigate based on notification type
    if (notification.type == 'booking_approved') {
      if (mounted) {
        // Navigate to CustomerHome with Approved tab selected
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CustomerHome(initialTabIndex: 1)),
        );
      }
    } else if (notification.type == 'booking_completed') {
      if (mounted) {
        // Navigate to BookingHistoryScreen with Completed tab (index 0)
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BookingHistoryScreen(initialTabIndex: 0)),
        );
      }
    } else if (notification.type == 'booking_cancelled') {
      if (mounted) {
        // Navigate to BookingHistoryScreen with Cancelled tab (index 1)
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BookingHistoryScreen(initialTabIndex: 1)),
        );
      }
    }
  }

  void _deleteNotification(NotificationData notification) async {
    if (notification.id == null) return;

    try {
      await NotificationManager.deleteNotification(notification.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user?.email == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: Colors.yellow[700],
          foregroundColor: Colors.black,
        ),
        body: const Center(
          child: Text('Please log in to view notifications'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.yellow[700],
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(_showUnreadOnly ? Icons.filter_list : Icons.filter_list_off),
            tooltip: _showUnreadOnly ? 'Show all' : 'Show unread only',
            onPressed: () {
              setState(() {
                _showUnreadOnly = !_showUnreadOnly;
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'mark_all_read') {
                _markAllAsRead();
              } else if (value == 'delete_all') {
                _deleteAllNotifications();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Mark all as read'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete all'),
                  ],
                ),
              ),
            ],
          ),
        ],
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
              selected: _selectedMenu == 'Home',
              selectedTileColor: Colors.yellow[100],
              onTap: () => _navigateFromDrawer('Home'),
            ),
            ListTile(
              leading: const Icon(Icons.book_online),
              title: const Text("Book a Service"),
              selected: _selectedMenu == 'Book',
              selectedTileColor: Colors.yellow[100],
              onTap: () => _navigateFromDrawer('Book'),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text("Booking History"),
              selected: _selectedMenu == 'History',
              selectedTileColor: Colors.yellow[100],
              onTap: () => _navigateFromDrawer('History'),
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text("Notifications"),
              selected: _selectedMenu == 'Notifications',
              selectedTileColor: Colors.yellow[100],
              onTap: () => _navigateFromDrawer('Notifications'),
            ),
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text("Account"),
              selected: _selectedMenu == 'Account',
              selectedTileColor: Colors.yellow[100],
              onTap: () => _navigateFromDrawer('Account'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: () => _navigateFromDrawer('Logout'),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<NotificationData>>(
        stream: NotificationManager.getUserNotifications(user!.email!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          final allNotifications = snapshot.data ?? [];
          final notifications = _showUnreadOnly
              ? allNotifications.where((n) => !n.isRead).toList()
              : allNotifications;

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _showUnreadOnly
                        ? 'No unread notifications'
                        : 'No notifications yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll see booking updates and important messages here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final color = _getNotificationColor(notification.type);
              final icon = _getNotificationIcon(notification.type);

              return Dismissible(
                key: Key(notification.id ?? 'notification_$index'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Notification'),
                      content: const Text(
                        'Are you sure you want to delete this notification?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (direction) {
                  _deleteNotification(notification);
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  elevation: notification.isRead ? 1 : 3,
                  color: notification.isRead ? null : Colors.blue[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: notification.isRead
                          ? Colors.grey[300]!
                          : color.withValues(alpha: 0.3),
                      width: notification.isRead ? 1 : 2,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.2),
                      child: Icon(icon, color: color),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          notification.message,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatDateTime(notification.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _handleNotificationTap(notification),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
