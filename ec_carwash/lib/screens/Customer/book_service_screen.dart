import 'package:flutter/material.dart';
import 'package:ec_carwash/data_models/products_data.dart';
import 'cart_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer_home.dart';

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

  final TextEditingController _plateController = TextEditingController();

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
      initialDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // --- SUBMIT BOOKING ---
  void _submitBooking() async {
    if (_cart.isEmpty ||
        _selectedDate == null ||
        _selectedTime == null ||
        _plateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select services, date, time, and plate number"),
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

    final plateNumber = _plateController.text.trim();
    final bookingData = {
      "userId": user.uid,
      "userEmail": user.email,
      "userName": user.displayName ?? "",
      "plateNumber": plateNumber,
      "services": _cart
          .map(
            (item) => {
              "serviceCode": item.serviceKey,
              "serviceName": item.serviceName,
              "vehicleType": item.vehicleType,
              "price": item.price,
            },
          )
          .toList(),
      "date": _selectedDate?.toIso8601String(),
      "time": _selectedTime?.format(context),
      "createdAt": FieldValue.serverTimestamp(),
    };

    try {
      // Save booking
      await FirebaseFirestore.instance.collection("Bookings").add(bookingData);

      // Save/update Customers collection
      final vehicleType = _cart.isNotEmpty ? _cart.first.vehicleType : "";
      final customerRef = FirebaseFirestore.instance.collection("Customers");
      final existing = await customerRef
          .where("plateNumber", isEqualTo: plateNumber)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        // New record
        await customerRef.add({
          "email": user.email,
          "name": user.displayName ?? "",
          "plateNumber": plateNumber,
          "vehicleType": vehicleType,
          "createdAt": FieldValue.serverTimestamp(),
        });
      } else {
        // Keep existing vehicleType
        final doc = existing.docs.first;
        final storedVehicle = doc["vehicleType"];
        await customerRef.doc(doc.id).update({
          "email": user.email,
          "name": user.displayName ?? "",
          "plateNumber": plateNumber,
          "vehicleType": storedVehicle,
        });
      }

      setState(() {
        _cart.clear();
        _selectedDate = null;
        _selectedTime = null;
        _plateController.clear();
        _isLoading = false;
      });

      if (Navigator.of(context).canPop()) Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Booking saved successfully")),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error saving booking: $e")));
    }
  }

  // --- SHOW CART ---
  void _showCart() {
    final total = _cart.fold<int>(0, (sum, item) => sum + item.price);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: Column(
                  children: [
                    const Text(
                      "Your Cart",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _cart.isEmpty
                          ? const Center(child: Text("Cart is empty"))
                          : ListView.builder(
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
                    ),
                    Text(
                      "Total: ₱$total",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_selectedDate != null && _selectedTime != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        "Selected: ${_selectedDate!.toLocal().toString().split(' ')[0]} at ${_selectedTime!.format(context)}",
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // 🔹 Plate Number
                    TextField(
                      controller: _plateController,
                      decoration: const InputDecoration(
                        labelText: "Plate Number",
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
                                  : "${_selectedDate!.toLocal()}".split(' ')[0],
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
                  ],
                ),
              ),
            ),
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // --- MAIN UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SelectVehicleScreen(
        onVehicleSelected: (vehicleType) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VehicleServicesScreen(
                vehicleType: vehicleType,
                onAddToCart: _addToCart,
                cart: _cart,
                showCart: _showCart,
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- VEHICLE SELECTION ---
// --- VEHICLE SELECTION ---
class SelectVehicleScreen extends StatelessWidget {
  final Function(String) onVehicleSelected;

  const SelectVehicleScreen({super.key, required this.onVehicleSelected});

  IconData _getVehicleIcon(String type) {
    switch (type.toLowerCase()) {
      case "car":
        return Icons.directions_car;
      case "suv":
        return Icons.directions_car_filled;
      case "van":
        return Icons.airport_shuttle;
      case "pick-up":
      case "pickup":
        return Icons.local_shipping;
      case "delivery truck":
      case "truck":
        return Icons.local_shipping;
      case "motorcycle":
      case "motorcycle s":
      case "motorcycle l":
        return Icons.motorcycle;
      case "tricycle":
        return Icons.electric_bike;
      default:
        return Icons.directions_car;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleTypes = <String>{};
    for (var entry in productsData.entries) {
      (entry.value['prices'] as Map<String, dynamic>).keys.forEach(
        vehicleTypes.add,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Select Vehicle")),
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

            // 🔹 Home
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text("Home"),
              selected: false, // Not highlighted
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomerHome()),
                );
              },
            ),

            // 🔹 Book a Service (highlighted)
            ListTile(
              leading: const Icon(Icons.book_online),
              title: const Text("Book a Service"),
              selected: true, // ✅ Highlight this item
              selectedTileColor: Colors.yellow[100], // background highlight
              textColor: Colors.black, // keep text readable
              iconColor: Colors.black, // keep icon readable
              onTap: () {
                Navigator.pop(context);
                // already on BookServiceScreen, so no need to push again
              },
            ),

            // 🔹 Booking History
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text("Booking History"),
              selected: false,
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to history screen
              },
            ),
            const Divider(),

            // 🔹 Logout
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: () {
                Navigator.pop(context);
                // TODO: Add logout logic
              },
            ),
          ],
        ),
      ),

      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: vehicleTypes.map((type) {
          return GestureDetector(
            onTap: () => onVehicleSelected(type),
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
}

// --- SERVICES SCREEN ---
class VehicleServicesScreen extends StatefulWidget {
  final String vehicleType;
  final Function(String, String, int) onAddToCart;
  final List<CartItem> cart;
  final VoidCallback showCart;

  const VehicleServicesScreen({
    super.key,
    required this.vehicleType,
    required this.onAddToCart,
    required this.cart,
    required this.showCart,
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
    final filteredServices = productsData.entries.where((entry) {
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
          // 🔽 FILTER BAR
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

          // 🔽 SERVICES GRID
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.9,
              children: filteredServices.map((entry) {
                final key = entry.key;
                final name = entry.value['name'];
                final prices = entry.value['prices'] as Map<String, dynamic>;
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
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 4),
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
