import 'package:flutter/material.dart';
import 'package:ec_carwash/data_models/services_data.dart';
import 'package:ec_carwash/data_models/booking_data_unified.dart';
import 'package:ec_carwash/data_models/relationship_manager.dart';
import 'package:ec_carwash/data_models/customer_data_unified.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'customer_home.dart';
import 'booking_history.dart';
import 'account_info_screen.dart';
import 'notifications_screen.dart';

class BookServiceScreen extends StatefulWidget {
  final Map<String, dynamic>? rebookData;

  const BookServiceScreen({super.key, this.rebookData});

  @override
  State<BookServiceScreen> createState() => _BookServiceScreenState();
}

class _BookServiceScreenState extends State<BookServiceScreen> {
  final List<CartItem> _cart = [];
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  // Services from Firestore
  List<Service> _services = [];
  bool _isLoadingServices = true;

  // User's vehicles
  List<Customer> _userVehicles = [];
  bool _isLoadingVehicles = true;
  Customer? _selectedVehicle;

  String _selectedMenu = "Book"; // for drawer highlighting

  // --- lifecycle ---
  @override
  void initState() {
    super.initState();
    _loadServices();
    _loadUserVehicles();
    _handleRebookData();
  }

  void _handleRebookData() {
    if (widget.rebookData == null) return;

    // Wait for services and vehicles to load before populating the cart
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      final rebookData = widget.rebookData!;
      final plateNumber = rebookData['plateNumber'] as String?;
      final services = (rebookData['services'] as List<dynamic>?) ?? [];

      // Find and select the vehicle by plate number
      if (plateNumber != null && _userVehicles.isNotEmpty) {
        try {
          final vehicle = _userVehicles.firstWhere(
            (v) => v.plateNumber.toUpperCase() == plateNumber.toUpperCase(),
          );

          setState(() {
            _selectedVehicle = vehicle;
          });
        } catch (e) {
          // Vehicle not found, user might need to add it
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Vehicle with plate $plateNumber not found. Please select a vehicle.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      // Populate cart with the services from the previous booking
      for (final serviceData in services) {
        final serviceCode = (serviceData['serviceCode'] ?? serviceData['code'] ?? '') as String;
        final serviceName = (serviceData['serviceName'] ?? '') as String;
        final vehicleType = (serviceData['vehicleType'] ?? '') as String;
        final price = (serviceData['price'] ?? 0) as num;

        if (serviceCode.isNotEmpty && serviceName.isNotEmpty && vehicleType.isNotEmpty) {
          setState(() {
            _cart.add(
              CartItem(
                serviceKey: serviceCode,
                serviceName: serviceName,
                vehicleType: vehicleType,
                price: price.toInt(),
              ),
            );
          });
        }
      }

      // Show a message to the user emphasizing they need to select date/time
      if (mounted && _cart.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Services loaded! Please select a new date and time for your booking.'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 4),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadServices() async {
    try {
      final services = await ServicesManager.getServices();
      setState(() {
        _services = services;
        _isLoadingServices = false;
      });
    } catch (e) {
      setState(() => _isLoadingServices = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading services: $e')),
        );
      }
    }
  }

  Future<void> _loadUserVehicles() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) {
      setState(() => _isLoadingVehicles = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Customers')
          .where('email', isEqualTo: user!.email)
          .get();

      final vehicles = snapshot.docs
          .map((doc) => Customer.fromJson(doc.data(), doc.id))
          .toList();

      setState(() {
        _userVehicles = vehicles;
        _isLoadingVehicles = false;
      });
    } catch (e) {
      setState(() => _isLoadingVehicles = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading vehicles: $e')),
        );
      }
    }
  }

  // Helper to get services data in the old format for compatibility
  Map<String, Map<String, dynamic>> get productsData {
    final Map<String, Map<String, dynamic>> data = {};
    for (final service in _services) {
      data[service.code] = {
        'name': service.name,
        'prices': service.prices,
      };
    }
    return data;
  }

  // --- CART FUNCTIONS ---
  void _addToCart(String key, String vehicleType, int price) {
    setState(() {
      _cart.add(
        CartItem(
          serviceKey: key,
          serviceName: productsData[key]!['name'],
          vehicleType: vehicleType,
          price: price,
        ),
      );
    });
  }

  void _removeFromCart(CartItem item) {
    setState(() {
      _cart.remove(item);
    });
  }

  // --- DATE & TIME PICKERS ---
  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: _selectedDate ?? DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  DateTime? _combinedSelectedDateTime() {
    if (_selectedDate == null || _selectedTime == null) return null;
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
  }

  // --- SUBMIT BOOKING (UNIFIED) ---
  Future<void> _submitBooking() async {
    if (_cart.isEmpty ||
        _selectedDate == null ||
        _selectedTime == null ||
        _selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please select a vehicle, services, date, and time",
          ),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You must be logged in to book a service"),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final selectedDateTime = _combinedSelectedDateTime()!;

      // Convert cart to BookingService list
      final services = _cart.map((item) => BookingService(
        serviceCode: item.serviceKey,
        serviceName: item.serviceName,
        vehicleType: item.vehicleType,
        price: item.price.toDouble(),
        quantity: 1,
      )).toList();

      // Use unified system - one call does everything!
      final (bookingId, customerId) = await RelationshipManager.createBookingWithCustomer(
        userName: user.displayName ?? 'Customer',
        userEmail: user.email!,
        userId: user.uid,
        plateNumber: _selectedVehicle!.plateNumber,
        contactNumber: _selectedVehicle!.contactNumber,
        vehicleType: _selectedVehicle!.vehicleType,
        scheduledDateTime: selectedDateTime,
        services: services,
        source: 'customer-app',
      );

      // reset UI
      setState(() {
        _cart.clear();
        _selectedDate = null;
        _selectedTime = null;
        _selectedVehicle = null;
        _isLoading = false;
      });

      // close sheet if open and give confirmation
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Booking created successfully! (ID: ${bookingId.substring(0, 8)}...)"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error creating booking: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- SHOW CART (bottom sheet) ---
  void _showCart() {
    final total = _cart.fold<int>(0, (sum, item) => sum + item.price);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final selectedDateTime = _combinedSelectedDateTime();
        final dateText = selectedDateTime != null
            ? "${selectedDateTime.year}-${selectedDateTime.month.toString().padLeft(2, '0')}-${selectedDateTime.day.toString().padLeft(2, '0')}"
            : null;
        final timeText = selectedDateTime != null
            ? TimeOfDay(
                hour: selectedDateTime.hour,
                minute: selectedDateTime.minute,
              ).format(context)
            : null;

        // allow sheet to scroll when keyboard is present
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    controller: controller,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "Your Cart",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_cart.isEmpty)
                          const Center(child: Text("Cart is empty"))
                        else
                          ListView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: _cart.length,
                            itemBuilder: (context, index) {
                              final item = _cart[index];
                              return ListTile(
                                title: Text(item.serviceName),
                                subtitle: Text(
                                  "${item.vehicleType} - ₱${item.price}",
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _removeFromCart(item),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 8),
                        Text(
                          "Total: ₱$total",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),

                        // show selected date/time if available
                        if (dateText != null && timeText != null) ...[
                          Text("Selected: $dateText at $timeText"),
                          const SizedBox(height: 12),
                        ],

                        // Vehicle selection
                        if (_userVehicles.isEmpty)
                          Card(
                            color: Colors.orange[50],
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  const Text(
                                    'No vehicles registered',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const AccountInfoScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Vehicle'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.yellow[700],
                                      foregroundColor: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          StatefulBuilder(
                            builder: (context, setDialogState) {
                              return DropdownButtonFormField<Customer>(
                                decoration: const InputDecoration(
                                  labelText: "Select Vehicle",
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.directions_car),
                                ),
                                value: _selectedVehicle,
                                items: _userVehicles.map((vehicle) {
                                  return DropdownMenuItem(
                                    value: vehicle,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          vehicle.plateNumber,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          '${vehicle.vehicleType ?? "Unknown"} • ${vehicle.contactNumber}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (vehicle) {
                                  setState(() {
                                    _selectedVehicle = vehicle;
                                    // Clear cart when vehicle changes
                                    _cart.clear();
                                  });
                                  Navigator.pop(context);
                                  _showCart();
                                },
                              );
                            }
                          ),
                        const SizedBox(height: 16),

                        // Date and Time Selection
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: (_selectedDate == null || _selectedTime == null)
                                  ? Colors.orange
                                  : Colors.green,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 20,
                                    color: (_selectedDate == null || _selectedTime == null)
                                        ? Colors.orange
                                        : Colors.green,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    (_selectedDate == null || _selectedTime == null)
                                        ? 'Select Date & Time (Required)'
                                        : 'Date & Time Selected',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: (_selectedDate == null || _selectedTime == null)
                                          ? Colors.orange
                                          : Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _pickDate,
                                      icon: const Icon(Icons.event, size: 18),
                                      label: Text(
                                        _selectedDate == null
                                            ? "Pick Date"
                                            : "${_selectedDate!.toLocal()}".split(' ')[0],
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _selectedDate == null
                                            ? Colors.orange
                                            : Colors.black,
                                        side: BorderSide(
                                          color: _selectedDate == null
                                              ? Colors.orange
                                              : Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _pickTime,
                                      icon: const Icon(Icons.access_time, size: 18),
                                      label: Text(
                                        _selectedTime == null
                                            ? "Pick Time"
                                            : _selectedTime!.format(context),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _selectedTime == null
                                            ? Colors.orange
                                            : Colors.black,
                                        side: BorderSide(
                                          color: _selectedTime == null
                                              ? Colors.orange
                                              : Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _submitBooking,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.yellow[700],
                            foregroundColor: Colors.black,
                          ),
                          child: const Text("Book Now"),
                        ),
                        const SizedBox(
                          height: 40,
                        ), // spacing so draggable handle looks neat
                      ],
                    ),
                  ),
                ),

                // loading overlay
                if (_isLoading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
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
      // already in Book, do nothing (we keep it highlighted)
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
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AccountInfoScreen()),
      );
    } else if (menu == 'Logout') {
      // TODO: implement logout
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while services or vehicles are loading
    if (_isLoadingServices || _isLoadingVehicles) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Book a Service"),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        // force hamburger menu even if we navigated here (so there's no back arrow)
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text("Book a Service"),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: _showCart,
              ),
              if (_cart.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.red,
                    child: Text(
                      "${_cart.length}",
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
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
              // highlight because this screen is "Book"
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

      // Vehicle and services selection
      body: _userVehicles.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      size: 100,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No vehicles registered',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Please add a vehicle to start booking services',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AccountInfoScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Vehicle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow[700],
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: _userVehicles.map((vehicle) {
                return GestureDetector(
                  onTap: () {
                    // Set selected vehicle and navigate to services
                    setState(() {
                      _selectedVehicle = vehicle;
                      _cart.clear(); // Clear cart when switching vehicles
                    });
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VehicleServicesScreen(
                          vehicleType: vehicle.vehicleType ?? '',
                          onAddToCart: _addToCart,
                          cart: _cart,
                          showCart: _showCart,
                          productsData: productsData,
                        ),
                      ),
                    );
                  },
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getVehicleIcon(vehicle.vehicleType ?? ''),
                            size: 50,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            vehicle.plateNumber,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            vehicle.vehicleType ?? 'Unknown',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  // map vehicle type strings to suitable icons (robust substring checks)
  IconData _getVehicleIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('suv')) {
      return Icons.directions_car_filled; // on modern Flutter
    }
    if (t.contains('pick') || t.contains('pickup')) {
      return Icons.fire_truck; // pickup-like
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

// --- SERVICES SCREEN ---
class VehicleServicesScreen extends StatefulWidget {
  final String vehicleType;
  final Function(String, String, int) onAddToCart;
  final List<CartItem> cart;
  final VoidCallback showCart;
  final Map<String, Map<String, dynamic>> productsData;

  const VehicleServicesScreen({
    super.key,
    required this.vehicleType,
    required this.onAddToCart,
    required this.cart,
    required this.showCart,
    required this.productsData,
  });

  @override
  State<VehicleServicesScreen> createState() => _VehicleServicesScreenState();
}

class _VehicleServicesScreenState extends State<VehicleServicesScreen> {
  String _selectedFilter = "ALL";
  final List<String> _filters = ["ALL", "EC", "Promo", "Upgrade"];

  bool _matchesFilter(String serviceKey) {
    if (_selectedFilter == "ALL") return true;
    return serviceKey.toLowerCase().startsWith(_selectedFilter.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final filteredServices = widget.productsData.entries.where((entry) {
      final prices = entry.value['prices'] as Map<String, dynamic>;
      return prices.containsKey(widget.vehicleType) &&
          _matchesFilter(entry.key);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("Services for ${widget.vehicleType}"),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: widget.showCart,
              ),
              if (widget.cart.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.red,
                    child: Text(
                      "${widget.cart.length}",
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(30),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final segmentWidth = constraints.maxWidth / _filters.length;
                final selectedIndex = _filters.indexOf(_selectedFilter);

                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      left: segmentWidth * selectedIndex,
                      child: Container(
                        width: segmentWidth,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.yellow[700],
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                    Row(
                      children: _filters.map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFilter = filter;
                              });
                            },
                            child: Container(
                              height: 40,
                              alignment: Alignment.center,
                              child: Text(
                                filter,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
          ),

          // Grid of service panels (2 per row)
          Expanded(
            child: filteredServices.isEmpty
                ? const Center(
                    child: Text("No services for this vehicle / filter"),
                  )
                : GridView.count(
                    crossAxisCount: 2,
                    padding: const EdgeInsets.all(16),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.95,
                    children: filteredServices.map((entry) {
                      final key = entry.key;
                      final name = entry.value['name'];
                      final prices =
                          entry.value['prices'] as Map<String, dynamic>;
                      final desc = entry.value['description'] ?? "";
                      final price = prices[widget.vehicleType] as int;

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                key,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                name,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  desc,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const Spacer(),
                              Text(
                                "₱$price",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => widget.onAddToCart(
                                    key,
                                    widget.vehicleType,
                                    price,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.yellow[700],
                                    foregroundColor: Colors.black,
                                  ),
                                  child: const Text("Add"),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
