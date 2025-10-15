import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ec_carwash/data_models/customer_data_unified.dart';
import 'package:ec_carwash/data_models/services_data.dart';
import 'customer_home.dart';
import 'book_service_screen.dart';
import 'booking_history.dart';
import 'notifications_screen.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;
  List<Customer> _userVehicles = [];
  bool _isLoading = true;
  List<String> _availableVehicleTypes = [];
  String _selectedMenu = "Account";

  @override
  void initState() {
    super.initState();
    _loadAccountInfo();
    _loadVehicleTypes();
  }

  Future<void> _loadAccountInfo() async {
    setState(() => _isLoading = true);

    _currentUser = _auth.currentUser;

    if (_currentUser != null) {
      await _loadUserVehicles();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadVehicleTypes() async {
    try {
      final services = await ServicesManager.getServices();
      final types = <String>{};

      for (final service in services) {
        types.addAll(service.prices.keys);
      }

      setState(() {
        _availableVehicleTypes = types.toList()..sort();
      });
    } catch (e) {
      // Fallback to empty list if services can't be loaded
      setState(() {
        _availableVehicleTypes = [];
      });
    }
  }

  Future<void> _loadUserVehicles() async {
    if (_currentUser?.email == null) return;

    try {
      // Get all customers with this user's email
      final snapshot = await _firestore
          .collection('Customers')
          .where('email', isEqualTo: _currentUser!.email)
          .get();

      final vehicles = snapshot.docs
          .map((doc) => Customer.fromJson(doc.data(), doc.id))
          .toList();

      setState(() {
        _userVehicles = vehicles;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading vehicles: $e')));
      }
    }
  }

  Future<bool> _isPlateNumberUnique(String plateNumber) async {
    try {
      final normalizedPlate = plateNumber.trim().toUpperCase();

      final snapshot = await _firestore
          .collection('Customers')
          .where('plateNumber', isEqualTo: normalizedPlate)
          .limit(1)
          .get();

      return snapshot.docs.isEmpty;
    } catch (e) {
      throw Exception('Error checking plate number: $e');
    }
  }

  Future<void> _showAddVehicleDialog() async {
    final plateController = TextEditingController();
    final contactController = TextEditingController();
    String? selectedVehicleType;
    bool isCheckingPlate = false;
    String? plateError;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Vehicle'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: plateController,
                      decoration: InputDecoration(
                        labelText: 'Plate Number *',
                        border: const OutlineInputBorder(),
                        errorText: plateError,
                        suffixIcon: isCheckingPlate
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (value) async {
                        if (value.trim().isEmpty) {
                          setDialogState(() {
                            plateError = null;
                            isCheckingPlate = false;
                          });
                          return;
                        }

                        setDialogState(() {
                          isCheckingPlate = true;
                          plateError = null;
                        });

                        // Debounce the check
                        await Future.delayed(const Duration(milliseconds: 500));

                        if (plateController.text.trim().toUpperCase() ==
                            value.trim().toUpperCase()) {
                          try {
                            final isUnique = await _isPlateNumberUnique(value);
                            setDialogState(() {
                              isCheckingPlate = false;
                              if (!isUnique) {
                                plateError =
                                    'This plate number is already registered';
                              }
                            });
                          } catch (e) {
                            setDialogState(() {
                              isCheckingPlate = false;
                              plateError = 'Error checking plate number';
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: contactController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Number *',
                        border: OutlineInputBorder(),
                        hintText: '09XXXXXXXXX',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Type *',
                        border: OutlineInputBorder(),
                      ),
                      items: _availableVehicleTypes.map((type) {
                        return DropdownMenuItem(value: type, child: Text(type));
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedVehicleType = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isCheckingPlate || plateError != null
                      ? null
                      : () async {
                          final plate = plateController.text.trim();
                          final contact = contactController.text.trim();

                          if (plate.isEmpty ||
                              contact.isEmpty ||
                              selectedVehicleType == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please fill in all fields'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          // Final validation
                          final isUnique = await _isPlateNumberUnique(plate);
                          if (!isUnique) {
                            setDialogState(() {
                              plateError =
                                  'This plate number is already registered';
                            });
                            return;
                          }

                          if (!context.mounted) return;
                          Navigator.pop(context);
                          await _addVehicle(
                            plate,
                            contact,
                            selectedVehicleType!,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow[700],
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Add Vehicle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addVehicle(
    String plateNumber,
    String contactNumber,
    String vehicleType,
  ) async {
    if (_currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      final newCustomer = Customer(
        name: _currentUser!.displayName ?? 'Customer',
        plateNumber: plateNumber.toUpperCase(),
        email: _currentUser!.email!,
        contactNumber: contactNumber,
        vehicleType: vehicleType,
        createdAt: DateTime.now(),
        lastVisit: DateTime.now(),
        source: 'customer-app',
      );

      await CustomerManager.saveCustomer(newCustomer);

      await _loadUserVehicles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding vehicle: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showEditContactDialog(Customer vehicle) async {
    final contactController = TextEditingController(
      text: vehicle.contactNumber,
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Contact Number'),
          content: TextField(
            controller: contactController,
            decoration: const InputDecoration(
              labelText: 'Contact Number',
              border: OutlineInputBorder(),
              hintText: '09XXXXXXXXX',
            ),
            keyboardType: TextInputType.phone,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newContact = contactController.text.trim();
                if (newContact.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Contact number cannot be empty'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                await _updateContactNumber(vehicle, newContact);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow[700],
                foregroundColor: Colors.black,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateContactNumber(Customer vehicle, String newContact) async {
    setState(() => _isLoading = true);

    try {
      final updated = vehicle.copyWith(contactNumber: newContact);
      await CustomerManager.saveCustomer(updated);
      await _loadUserVehicles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact number updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating contact number: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- Drawer navigation helper ---
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
        MaterialPageRoute(builder: (context) => const BookingHistoryScreen()),
      );
    } else if (menu == 'Notifications') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NotificationsScreen()),
      );
    } else if (menu == 'Account') {
      // already in Account, do nothing (we keep it highlighted)
    } else if (menu == 'Logout') {
      // TODO: implement logout
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account Information')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account Information')),
        body: const Center(
          child: Text('Please log in to view account information'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Information'),
        backgroundColor: Colors.yellow[700],
        foregroundColor: Colors.black,
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
      body: RefreshIndicator(
        onRefresh: _loadAccountInfo,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.yellow[700],
                        backgroundImage: _currentUser!.photoURL != null
                            ? NetworkImage(_currentUser!.photoURL!)
                            : null,
                        child: _currentUser!.photoURL == null
                            ? Text(
                                _currentUser!.displayName
                                        ?.substring(0, 1)
                                        .toUpperCase() ??
                                    'U',
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _currentUser!.displayName ?? 'User',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentUser!.email ?? '',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified,
                              color: Colors.green[700],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Verified Google Account',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Vehicles Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Vehicles',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddVehicleDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Vehicle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow[700],
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Vehicles List
              if (_userVehicles.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.directions_car_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No vehicles registered yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first vehicle to start booking services',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _userVehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = _userVehicles[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: Colors.yellow[700],
                          child: Icon(
                            _getVehicleIcon(vehicle.vehicleType ?? ''),
                            color: Colors.black,
                          ),
                        ),
                        title: Text(
                          vehicle.plateNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Type: ${vehicle.vehicleType ?? "Not specified"}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.phone, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  vehicle.contactNumber,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                            if (vehicle.totalVisits > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Visits: ${vehicle.totalVisits} | Spent: ₱${vehicle.totalSpent.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showEditContactDialog(vehicle),
                          tooltip: 'Edit contact number',
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getVehicleIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('suv')) {
      return Icons.directions_car_filled;
    }
    if (t.contains('pick') || t.contains('pickup')) {
      return Icons.fire_truck;
    }
    if (t.contains('truck') || t.contains('delivery')) {
      return Icons.local_shipping;
    }
    if (t.contains('van')) {
      return Icons.airport_shuttle;
    }
    if (t.contains('motor') || t.contains('bike')) {
      return Icons.motorcycle;
    }
    if (t.contains('tricycle') || t.contains('trike')) {
      return Icons.electric_bike;
    }
    if (t.contains('car') || t.contains('sedan')) {
      return Icons.directions_car;
    }
    return Icons.directions_car;
  }
}
