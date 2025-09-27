import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Firestore
import 'package:ec_carwash/data_models/services_data.dart';
import 'package:ec_carwash/data_models/inventory_data.dart';
import 'package:ec_carwash/data_models/customer_data.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final List<Map<String, dynamic>> cart = [];

  Customer? currentCustomer;
  String? _currentCustomerId;
  String? _vehicleTypeForCustomer; // ← use this; if null we’ll ask once

  // Controllers for customer form
  final TextEditingController nameController = TextEditingController();
  final TextEditingController plateController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  // Time picker state (defaults to now)
  TimeOfDay _selectedTime = TimeOfDay.now();

  String _formatTimeOfDay(BuildContext ctx, TimeOfDay tod) {
    try {
      return MaterialLocalizations.of(ctx).formatTimeOfDay(tod);
    } catch (_) {
      final h = tod.hourOfPeriod.toString().padLeft(2, '0');
      final m = tod.minute.toString().padLeft(2, '0');
      final ap = tod.period == DayPeriod.am ? 'AM' : 'PM';
      return '$h:$m $ap';
    }
  }

  bool isSearching = false;
  List<Customer> _searchResults = <Customer>[];
  List<Customer> get searchResults => _searchResults;

  // Services data
  List<Service> _services = [];
  bool _isLoadingServices = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
    _searchResults = <Customer>[];
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
      debugPrint('Error loading services: $e');
    }
  }

  Map<String, Map<String, dynamic>> get servicesData {
    final Map<String, Map<String, dynamic>> data = {};
    for (final service in _services) {
      data[service.code] = {'name': service.name, 'prices': service.prices};
    }
    return data;
  }

  final Map<String, String> serviceToInventoryMap = {
    'EC1': 'INV001',
    'EC2': 'INV003',
    'EC3': 'INV004',
    'EC4': 'INV005',
    'EC6': 'INV011',
    'EC7': 'INV007',
    'EC9': 'INV006',
    'EC14': 'INV006',
  };

  double get total => cart.fold(0.0, (total, item) {
    final price = (item["price"] ?? 0) as num;
    final qty = (item["quantity"] ?? 0) as int;
    return total + price.toDouble() * qty;
  });

  Future<bool> _checkInventoryAvailability(String code) async => true;

  Future<void> _consumeInventory(String code, int quantity) async {
    final inventoryId = serviceToInventoryMap[code];
    if (inventoryId != null) {
      await InventoryManager.consumeStock(inventoryId, quantity);
    }
  }

  Future<void> addToCart(String code, String category, double price) async {
    final isAvailable = await _checkInventoryAvailability(code);
    if (!isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Insufficient inventory for this service'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      final index = cart.indexWhere(
        (item) => item["code"] == code && item["category"] == category,
      );
      if (index >= 0) {
        cart[index]["quantity"] = (cart[index]["quantity"] ?? 0) + 1;
      } else {
        cart.add({
          "code": code,
          "category": category,
          "price": price.toDouble(),
          "quantity": 1,
        });
      }
    });
  }

  void removeFromCart(int index) {
    setState(() {
      if (cart[index]["quantity"] > 1) {
        cart[index]["quantity"] -= 1;
      } else {
        cart.removeAt(index);
      }
    });
  }

  void _clearCustomer() {
    setState(() {
      currentCustomer = null;
      _currentCustomerId = null;
      _vehicleTypeForCustomer = null;
      nameController.clear();
      plateController.clear();
      emailController.clear();
      phoneController.clear();
      _searchResults.clear();
    });
  }

  // Read Firestore directly for reliable keys (email/contactNumber/vehicleType)
  Future<void> _loadCustomerByPlateFromFirestore(String plate) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Customers')
          .where('plateNumber', isEqualTo: plate.toUpperCase())
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        setState(() {
          _currentCustomerId = null;
          _vehicleTypeForCustomer = null;
        });
        return;
      }

      final doc = snap.docs.first;
      final data = doc.data();

      nameController.text = (data['name'] ?? '').toString();
      plateController.text = (data['plateNumber'] ?? '').toString();
      emailController.text = (data['email'] ?? '').toString();
      phoneController.text = (data['contactNumber'] ?? '').toString();

      setState(() {
        _currentCustomerId = doc.id;
        _vehicleTypeForCustomer = (data['vehicleType'] ?? '')?.toString();
      });
    } catch (e) {
      debugPrint('Failed to load customer by plate: $e');
    }
  }

  void _searchByPlate(String plateNumber) async {
    if (plateNumber.trim().length >= 3) {
      setState(() => isSearching = true);
      await _loadCustomerByPlateFromFirestore(plateNumber.trim());
      setState(() => isSearching = false);
    }
  }

  void _searchByName(String name) async {
    if (name.trim().length >= 2) {
      setState(() => isSearching = true);
      try {
        final customers = await CustomerService.searchCustomersByName(name);
        setState(() {
          _searchResults = customers;
          isSearching = false;
        });
      } catch (e) {
        setState(() {
          _searchResults.clear();
          isSearching = false;
        });
      }
    } else {
      setState(() => _searchResults.clear());
    }
  }

  Future<void> _selectCustomer(Customer customer) async {
    setState(() {
      currentCustomer = customer;
      nameController.text = customer.name;
      plateController.text = customer.plateNumber;
    });
    await _loadCustomerByPlateFromFirestore(customer.plateNumber);
    setState(() {
      _searchResults.clear();
      isSearching = false;
    });
  }

  // ---------- NEW: Upsert by plateNumber in 'Customers' ----------
  Future<String> _saveOrUpdateCustomerByPlate(Customer base) async {
    final col = FirebaseFirestore.instance.collection('Customers');
    final plate = base.plateNumber.toUpperCase();

    final query = await col
        .where('plateNumber', isEqualTo: plate)
        .limit(1)
        .get();

    // Common data to write
    final Map<String, dynamic> data = {
      'name': base.name,
      'plateNumber': plate,
      'email': base.email,
      'contactNumber': base.phoneNumber,
      if (_vehicleTypeForCustomer != null &&
          _vehicleTypeForCustomer!.isNotEmpty)
        'vehicleType': _vehicleTypeForCustomer,
      'lastVisit': base.lastVisit.toIso8601String(),
    };

    if (query.docs.isNotEmpty) {
      final id = query.docs.first.id;
      await col.doc(id).set(data, SetOptions(merge: true));
      return id; // updated existing
    } else {
      data['createdAt'] = DateTime.now().toIso8601String();
      final doc = await col.add(data);
      return doc.id; // created new
    }
  }
  // ---------------------------------------------------------------

  void _saveCustomer() async {
    if (nameController.text.isEmpty || plateController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name and Plate Number are required')),
        );
      }
      return;
    }

    try {
      final base = Customer(
        id: currentCustomer?.id,
        name: nameController.text.trim(),
        plateNumber: plateController.text.trim().toUpperCase(),
        email: emailController.text.trim(),
        phoneNumber: phoneController.text.trim(),
        createdAt: currentCustomer?.createdAt ?? DateTime.now(),
        lastVisit: DateTime.now(),
        vehicleType: _vehicleTypeForCustomer,
      );

      // ⬇️ Use the upsert-by-plate logic (update if exists, create if not)
      final customerId = await _saveOrUpdateCustomerByPlate(base);

      setState(() {
        currentCustomer = base.copyWith(id: customerId);
        _currentCustomerId = customerId;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving customer: $e')));
      }
    }
  }

  // Add service: if saved vehicleType exists, use it; else ask once.
  Future<void> _handleAddService(String code) async {
    final product = servicesData[code];
    if (product == null) return;

    final prices = (product["prices"] as Map<String, dynamic>);
    final vt = _vehicleTypeForCustomer;

    if (vt != null && vt.isNotEmpty && prices.containsKey(vt)) {
      final price = (prices[vt] as num).toDouble();
      await _addSingleCodeToCart(code, vt, price);
      return;
    }

    _showVehicleTypeDialog(code); // ask only if not saved
  }

  // ⬇️ Dialog now has NO checkbox; it only lets user pick once when none is saved
  void _showVehicleTypeDialog(String code) {
    final product = servicesData[code];
    if (product == null) return;

    final prices = product["prices"] as Map<String, dynamic>;
    final priceEntries = prices.entries.toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add $code to Cart'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose the vehicle type for pricing:'),
              const SizedBox(height: 16),
              ...priceEntries.map((entry) {
                final vehicleType = entry.key;
                final price = (entry.value as num).toDouble();
                IconData icon = Icons.directions_car;
                Color color = Colors.blue;

                if (vehicleType.contains('Motorcycle')) {
                  icon = Icons.motorcycle;
                  color = Colors.green;
                } else if (vehicleType.contains('Truck')) {
                  icon = Icons.local_shipping;
                  color = Colors.red;
                } else if (vehicleType.contains('Van') ||
                    vehicleType.contains('SUV')) {
                  icon = Icons.airport_shuttle;
                  color = Colors.orange;
                } else if (vehicleType.contains('Tricycle')) {
                  icon = Icons.pedal_bike;
                  color = Colors.purple;
                }

                return ListTile(
                  leading: Icon(icon, color: color),
                  title: Text(vehicleType),
                  subtitle: Text('₱${price.toStringAsFixed(2)}'),
                  onTap: () async {
                    Navigator.pop(context);
                    // Remember automatically the first time (since nothing saved yet)
                    await _addSingleCodeToCart(
                      code,
                      vehicleType,
                      price,
                      remember: true,
                    );
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _persistVehicleTypeIfNeeded(
    String category,
    bool remember,
  ) async {
    if (_currentCustomerId == null) return;

    final hasSaved =
        _vehicleTypeForCustomer != null && _vehicleTypeForCustomer!.isNotEmpty;
    final changing = _vehicleTypeForCustomer != category;
    final shouldPersist = !hasSaved || remember;

    if (changing && shouldPersist) {
      await FirebaseFirestore.instance
          .collection('Customers')
          .doc(_currentCustomerId)
          .set({'vehicleType': category}, SetOptions(merge: true));

      setState(() {
        _vehicleTypeForCustomer = category;
      });
    }
  }

  Future<void> _addSingleCodeToCart(
    String code,
    String category,
    double price, {
    bool remember = false,
  }) async {
    await addToCart(code, category, price);
    await _persistVehicleTypeIfNeeded(category, remember);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $code ($category) to cart'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingServices) {
      return const Center(child: CircularProgressIndicator());
    }

    final isWide = MediaQuery.of(context).size.width > 700;
    final codes = servicesData.keys.toList();

    codes.sort((a, b) {
      int getSortPriority(String code) {
        if (code.startsWith('EC')) return 1;
        if (code.startsWith('UPGRADE')) return 2;
        if (code.startsWith('PROMO')) return 3;
        return 4;
      }

      int getCodeNumber(String code) {
        final numStr = code.replaceAll(RegExp(r'[^0-9]'), '');
        return int.tryParse(numStr) ?? 0;
      }

      final pa = getSortPriority(a), pb = getSortPriority(b);
      if (pa != pb) return pa.compareTo(pb);
      return getCodeNumber(a).compareTo(getCodeNumber(b));
    });

    return Row(
      children: [
        // Product Codes Grid
        Expanded(
          flex: 4,
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 1400
                  ? 6
                  : MediaQuery.of(context).size.width > 1200
                  ? 5
                  : 4,
              childAspectRatio: 0.85,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: codes.length,
            itemBuilder: (context, index) {
              final code = codes[index];
              final product = servicesData[code];
              if (product == null) return const SizedBox();

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () =>
                      _handleAddService(code), // auto-vehicleType or ask once
                  // ⛔ removed onLongPress to prevent changing when saved
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, Color(0xFFF8F9FA), Colors.white],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade800,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              code,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Center(
                              child: Text(
                                product["name"],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                  height: 1.3,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Side panel
        if (isWide)
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(flex: 2, child: _buildCustomerForm()),
                Expanded(flex: 3, child: _buildCart()),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCustomerForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Colors.grey),
                const SizedBox(width: 8),
                const Text(
                  "Customer Information",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const Spacer(),
                if (_currentCustomerId != null || currentCustomer != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearCustomer,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Plate Number Field (autofill trigger)
            TextField(
              controller: plateController,
              decoration: const InputDecoration(
                labelText: "Plate Number",
                prefixIcon: Icon(Icons.directions_car),
                border: OutlineInputBorder(),
              ),
              onChanged: _searchByPlate,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),

            // Customer Name Field
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Customer Name",
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              onChanged: _searchByName,
            ),
            const SizedBox(height: 12),

            // Email Field
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),

            // Contact Number Field
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: "Contact Number",
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),

            // Time Picker
            Row(
              children: [
                const Icon(Icons.access_time, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Time: ${_formatTimeOfDay(context, _selectedTime)}",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text("Pick Time"),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _selectedTime,
                    );
                    if (picked != null) {
                      setState(() => _selectedTime = picked);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search Results
            if (searchResults.isNotEmpty)
              Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: searchResults.length,
                  itemBuilder: (context, index) {
                    final customer = searchResults[index];
                    return ListTile(
                      title: Text(customer.name),
                      subtitle: Text(customer.plateNumber),
                      onTap: () => _selectCustomer(customer),
                    );
                  },
                ),
              ),
            if (searchResults.isNotEmpty) const SizedBox(height: 16),

            // Tip text updated (no override path now)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Tap a service to add it. If the customer has a saved vehicle type, it will be used automatically.",
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Save Customer Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveCustomer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow.shade700,
                  foregroundColor: Colors.black,
                ),
                child: Text(
                  _currentCustomerId == null && (currentCustomer?.id == null)
                      ? "Save New Customer"
                      : "Update Customer",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCart() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: const Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        children: [
          const ListTile(
            title: Text("Cart", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: cart.isEmpty
                ? const Center(child: Text("No items in cart"))
                : ListView.builder(
                    itemCount: cart.length,
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      final price = (item["price"] as num).toDouble();
                      final qty = (item["quantity"] ?? 0) as int;
                      final subtotal = price * qty;

                      return ListTile(
                        title: Text("${item["code"]} - ${item["category"]}"),
                        subtitle: Text(
                          "₱${price.toStringAsFixed(2)} x $qty = ₱${subtotal.toStringAsFixed(2)}",
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => removeFromCart(index),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total: ₱${total.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                ElevatedButton(
                  onPressed: cart.isEmpty ? null : _showCartSummary,
                  child: const Text("Checkout"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCartSummary() {
    final cashController = TextEditingController();
    double change = 0.0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Summary Cart"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...cart.map((item) {
                      final price = (item["price"] as num).toDouble();
                      final qty = (item["quantity"] ?? 0) as int;
                      final subtotal = price * qty;
                      return ListTile(
                        dense: true,
                        title: Text("${item["code"]} - ${item["category"]}"),
                        subtitle: Text(
                          "₱${price.toStringAsFixed(2)} x $qty = ₱${subtotal.toStringAsFixed(2)}",
                        ),
                      );
                    }),
                    const Divider(),
                    Text(
                      "Total: ₱${total.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: cashController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "Cash",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        final cash = double.tryParse(val) ?? 0;
                        setState(() {
                          change = cash - total;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Change: ₱${change.toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: (change < 0)
                      ? null
                      : () async {
                          for (final item in cart) {
                            final code = item["code"] as String;
                            final quantity = item["quantity"] as int;
                            await _consumeInventory(code, quantity);
                          }

                          await _saveTransactionToFirestore(
                            cash: double.tryParse(cashController.text) ?? 0,
                            change: change,
                          );

                          if (mounted) {
                            Navigator.pop(context);
                            _showReceipt(
                              cash: double.tryParse(cashController.text) ?? 0,
                              change: change,
                            );
                          }
                        },
                  child: const Text("Payment"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveTransactionToFirestore({
    required double cash,
    required double change,
  }) async {
    try {
      final now = DateTime.now();
      final txnDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // build customer data
      final customerMap = {
        "id": _currentCustomerId ?? currentCustomer?.id,
        "plateNumber": plateController.text.trim().toUpperCase(),
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
        "contactNumber": phoneController.text.trim(),
        "vehicleType": _vehicleTypeForCustomer,
      };

      // build cart items
      final items = cart.map((e) {
        final price = (e["price"] as num).toDouble();
        final qty = (e["quantity"] as int);
        final subtotal = price * qty;
        return {
          "serviceCode": e["code"],
          "vehicleType": e["category"],
          "price": price,
          "quantity": qty,
          "subtotal": subtotal,
        };
      }).toList();

      // compute total explicitly
      final double totalAmount = items.fold(
        0.0,
        (total, item) => total + (item["subtotal"] as double),
      );

      final payload = {
        "customer": customerMap,
        "items": items,
        "total": totalAmount, // ✅ ensure total saved
        "cash": cash,
        "change": change,
        "date": Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
        "time": {
          "hour": _selectedTime.hour,
          "minute": _selectedTime.minute,
          "formatted": _formatTimeOfDay(context, _selectedTime),
        },
        "createdAt":
            FieldValue.serverTimestamp(), // ✅ serverTimestamp for consistency
        "transactionAt": Timestamp.fromDate(txnDateTime),
        "status": "paid",
      };

      // Save transaction
      final transactionRef = await FirebaseFirestore.instance.collection("Transactions").add(payload);

      // Also create a booking record with "approved" status (since POS transactions are immediate)
      await _createBookingFromPOSTransaction(transactionRef.id, txnDateTime, customerMap, items, totalAmount);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error saving transaction: $e")));
      }
    }
  }

  Future<void> _createBookingFromPOSTransaction(
    String transactionId,
    DateTime txnDateTime,
    Map<String, dynamic> customerMap,
    List<Map<String, dynamic>> items,
    double totalAmount,
  ) async {
    try {
      // Convert POS items to booking services format
      final services = items.map((item) {
        return {
          "serviceCode": item["serviceCode"],
          "serviceName": _getServiceName(item["serviceCode"]),
          "vehicleType": item["vehicleType"],
          "price": item["price"],
        };
      }).toList();

      // Create booking data with "approved" status (POS transactions are immediate)
      final bookingData = {
        "userId": customerMap["id"] ?? "",
        "userEmail": customerMap["email"] ?? "",
        "userName": customerMap["name"] ?? "",
        "plateNumber": customerMap["plateNumber"] ?? "",
        "contactNumber": customerMap["contactNumber"] ?? "",
        "selectedDateTime": Timestamp.fromDate(txnDateTime),
        "date": txnDateTime.toIso8601String(),
        "time": "${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}",
        "services": services,
        "status": "approved", // POS transactions are automatically approved
        "createdAt": FieldValue.serverTimestamp(),
        "source": "pos", // Mark as coming from POS
        "transactionId": transactionId, // Reference to the transaction
      };

      // Save to Bookings collection
      await FirebaseFirestore.instance.collection("Bookings").add(bookingData);
    } catch (e) {
      // Log error but don't fail the transaction
      debugPrint('Failed to create booking from POS transaction: $e');
    }
  }

  String _getServiceName(String serviceCode) {
    // Get service name from servicesData
    final service = servicesData[serviceCode];
    return service?['name'] ?? serviceCode;
  }

  void _showReceipt({required double cash, required double change}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Receipt"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...cart.map((item) {
                  final price = (item["price"] as num).toDouble();
                  final qty = (item["quantity"] ?? 0) as int;
                  final subtotal = price * qty;
                  return Text(
                    "${item["code"]} - ${item["category"]}: ₱${subtotal.toStringAsFixed(2)}",
                  );
                }),
                const Divider(),
                Text("Total: ₱${total.toStringAsFixed(2)}"),
                Text("Cash: ₱${cash.toStringAsFixed(2)}"),
                Text("Change: ₱${change.toStringAsFixed(2)}"),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
            ElevatedButton(
              onPressed: () async {
                final pdf = pw.Document();

                final String formattedTime = _formatTimeOfDay(
                  this.context,
                  _selectedTime,
                );
                final String formattedDate = DateTime.now()
                    .toString()
                    .substring(0, 10);

                final robotoRegular = pw.Font.ttf(
                  await rootBundle.load("Roboto-Regular.ttf"),
                );
                final robotoBold = pw.Font.ttf(
                  await rootBundle.load("Roboto-Bold.ttf"),
                );

                pdf.addPage(
                  pw.Page(
                    build: (pw.Context ctx) {
                      return pw.DefaultTextStyle(
                        style: pw.TextStyle(font: robotoRegular, fontSize: 12),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              "Carwash Receipt",
                              style: pw.TextStyle(
                                font: robotoBold,
                                fontSize: 20,
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            pw.Text(
                              "Date: $formattedDate   Time: $formattedTime",
                            ),
                            pw.SizedBox(height: 10),
                            pw.Table(
                              border: pw.TableBorder.all(width: 0.5),
                              columnWidths: {
                                0: const pw.FlexColumnWidth(2),
                                1: const pw.FlexColumnWidth(1),
                                2: const pw.FlexColumnWidth(1),
                                3: const pw.FlexColumnWidth(1.5),
                              },
                              children: [
                                pw.TableRow(
                                  decoration: const pw.BoxDecoration(
                                    color: PdfColors.grey300,
                                  ),
                                  children: [
                                    _cell("Service", robotoBold),
                                    _cell("Qty", robotoBold),
                                    _cell("Price", robotoBold),
                                    _cell("Subtotal", robotoBold),
                                  ],
                                ),
                                ...cart.map((item) {
                                  final price = (item["price"] as num)
                                      .toDouble();
                                  final qty = (item["quantity"] ?? 0) as int;
                                  final subtotal = price * qty;
                                  return pw.TableRow(
                                    children: [
                                      _cell(
                                        "${item["code"]} - ${item["category"]}",
                                        robotoRegular,
                                      ),
                                      _cell("$qty", robotoRegular),
                                      _cell(
                                        "₱${price.toStringAsFixed(2)}",
                                        robotoRegular,
                                      ),
                                      _cell(
                                        "₱${subtotal.toStringAsFixed(2)}",
                                        robotoRegular,
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                            pw.SizedBox(height: 12),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.end,
                              children: [
                                pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                                  children: [
                                    pw.Text(
                                      "Total: ₱${total.toStringAsFixed(2)}",
                                      style: pw.TextStyle(font: robotoBold),
                                    ),
                                    pw.Text(
                                      "Cash: ₱${cash.toStringAsFixed(2)}",
                                    ),
                                    pw.Text(
                                      "Change: ₱${change.toStringAsFixed(2)}",
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 20),
                            pw.Text(
                              "Thank you for your payment!",
                              style: pw.TextStyle(
                                font: robotoRegular,
                                fontStyle: pw.FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );

                await Printing.sharePdf(
                  bytes: await pdf.save(),
                  filename: "receipt.pdf",
                );

                if (mounted) {
                  setState(() => cart.clear());
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text("Print as PDF"),
            ),
          ],
        );
      },
    );
  }
}

pw.Widget _cell(String text, pw.Font font) => pw.Padding(
  padding: const pw.EdgeInsets.all(4),
  child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 12)),
);
