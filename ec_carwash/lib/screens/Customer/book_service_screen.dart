import 'package:flutter/material.dart';
import 'package:ec_carwash/data_models/products_data.dart';
import 'cart_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // pick date
  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // pick time
  void _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // add item to cart
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

  // remove item from cart
  void _removeFromCart(CartItem item) {
    setState(() {
      _cart.remove(item);
    });
  }

  // submit booking with full-screen loading
  void _submitBooking() async {
    if (_cart.isEmpty || _selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select services, date, and time")),
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

    final bookingData = {
      "userId": user.uid,
      "userEmail": user.email,
      "userName": user.displayName ?? "",
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
      await FirebaseFirestore.instance.collection("Bookings").add(bookingData);

      setState(() {
        _cart.clear();
        _selectedDate = null;
        _selectedTime = null;
        _isLoading = false;
      });

      // Close bottom sheet if open
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

  // show cart in bottom sheet
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
                    const SizedBox(height: 16),

                    // Date & Time pickers
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

                    // Submit button
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

            // Full-screen loading overlay
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
      body: ListView(
        children: productsData.entries.map((entry) {
          final key = entry.key;
          final name = entry.value['name'];
          final prices = entry.value['prices'] as Map<String, dynamic>;

          return ExpansionTile(
            leading: const Icon(Icons.cleaning_services),
            title: Text(name),
            children: prices.entries.map((p) {
              return ListTile(
                title: Text("${p.key} - ₱${p.value}"),
                trailing: ElevatedButton(
                  onPressed: () => _addToCart(key, p.key, p.value as int),
                  child: const Text("Add"),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}
