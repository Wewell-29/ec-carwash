import 'package:flutter/material.dart';
import 'package:ec_carwash/data_models/services_data.dart';
import 'package:ec_carwash/data_models/booking_data_unified.dart';
import 'package:ec_carwash/data_models/relationship_manager.dart';
import 'cart_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'customer_home.dart';
import 'booking_history.dart';

class BookServiceScreen extends StatefulWidget {
  const BookServiceScreen({super.key});

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

  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  String _selectedMenu = "Book"; // for drawer highlighting

  // --- lifecycle ---
  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void dispose() {
    _plateController.dispose();
    _contactController.dispose();
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
        _plateController.text.trim().isEmpty ||
        _contactController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please select services, date, time, plate number, and contact number",
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
      final plateNumber = _plateController.text.trim();
      final contactNumber = _contactController.text.trim();
      final selectedDateTime = _combinedSelectedDateTime()!;
      final vehicleType = _cart.isNotEmpty ? _cart.first.vehicleType : null;

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
        plateNumber: plateNumber,
        contactNumber: contactNumber,
        vehicleType: vehicleType,
        scheduledDateTime: selectedDateTime,
        services: services,
        source: 'customer-app',
      );

      // reset UI
      setState(() {
        _cart.clear();
        _selectedDate = null;
        _selectedTime = null;
        _plateController.clear();
        _contactController.clear();
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

                        // Plate number
                        TextField(
                          controller: _plateController,
                          decoration: const InputDecoration(
                            labelText: "Plate Number",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Contact number
                        TextField(
                          controller: _contactController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: "Contact Number",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _pickDate,
                                child: Text(
                                  _selectedDate == null
                                      ? "Pick Date"
                                      : "${_selectedDate!.toLocal()}".split(
                                          ' ',
                                        )[0],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _pickTime,
                                child: Text(
                                  _selectedTime == null
                                      ? "Pick Time"
                                      : _selectedTime!.format(context),
                                ),
                              ),
                            ),
                          ],
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
    } else if (menu == 'Logout') {
      // TODO: implement logout
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while services are loading
    if (_isLoadingServices) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Book a Service"),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Build list of vehicle types from productsData
    final vehicleTypes = <String>{};
    for (var entry in productsData.entries) {
      final prices = entry.value['prices'] as Map<String, dynamic>;
      for (var k in prices.keys) {
        vehicleTypes.add(k.toString());
      }
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
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: () => _navigateFromDrawer('Logout'),
            ),
          ],
        ),
      ),

      // Vehicle selection grid (2 columns)
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: vehicleTypes.map((type) {
          return GestureDetector(
            onTap: () {
              // go to services for this vehicle
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VehicleServicesScreen(
                    vehicleType: type,
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_getVehicleIcon(type), size: 50, color: Colors.blue),
                  const SizedBox(height: 8),
                  Text(
                    type,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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
