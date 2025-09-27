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

  // Vehicle type for the customer form
  String? _selectedVehicleType;

  // Time picker state (defaults to now)
  TimeOfDay _selectedTime = TimeOfDay.now();

  // UI state for showing new customer form
  bool _showNewCustomerForm = false;

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
  bool _hasSearched = false;
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
      _selectedVehicleType = null;
      nameController.clear();
      plateController.clear();
      emailController.clear();
      phoneController.clear();
      _searchResults.clear();
      isSearching = false;
      _hasSearched = false; // Reset search state to return cart to normal size
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
        _selectedVehicleType = _vehicleTypeForCustomer;
      });
    } catch (e) {
      debugPrint('Failed to load customer by plate: $e');
    }
  }


  void _performSearch(String query) async {
    setState(() {
      isSearching = true;
      _hasSearched = false;
      _searchResults.clear();
    });

    try {
      // Try plate search first (more specific)
      if (query.length >= 3) {
        final customer = await CustomerService.getCustomerByPlateNumber(query);
        if (customer != null) {
          setState(() {
            _searchResults = [customer];
            isSearching = false;
            _hasSearched = true;
          });
          return;
        }
      }

      // If no plate results, try name search
      if (query.length >= 2) {
        // Try different case variations
        final variations = [
          query.trim(),
          query.toLowerCase(),
          query.trim().toLowerCase().replaceFirst(query.trim().toLowerCase()[0], query.trim().toLowerCase()[0].toUpperCase()),
        ];

        for (final variation in variations) {
          try {
            final customers = await CustomerService.searchCustomersByName(variation);
            if (customers.isNotEmpty) {
              setState(() {
                _searchResults = customers;
                isSearching = false;
                _hasSearched = true;
              });
              return;
            }
          } catch (e) {
            debugPrint('Search variation failed for "$variation": $e');
          }
        }
      }

      // No results found
      setState(() {
        _searchResults.clear();
        isSearching = false;
        _hasSearched = true;
      });
    } catch (e) {
      setState(() {
        _searchResults.clear();
        isSearching = false;
        _hasSearched = true;
      });
      debugPrint('Search failed: $e');
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
      _hasSearched = false; // Reset search state to return cart to normal size
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
      if (_selectedVehicleType != null && _selectedVehicleType!.isNotEmpty)
        'vehicleType': _selectedVehicleType,
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
        vehicleType: _selectedVehicleType,
      );

      // ⬇️ Use the upsert-by-plate logic (update if exists, create if not)
      final customerId = await _saveOrUpdateCustomerByPlate(base);

      setState(() {
        currentCustomer = base.copyWith(id: customerId);
        _currentCustomerId = customerId;
        _vehicleTypeForCustomer = _selectedVehicleType;
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
                // Dynamic sizing based on search state
                Expanded(
                  flex: _getCustomerFormFlex(),
                  child: _buildCustomerForm()
                ),
                Expanded(
                  flex: _getCartFlex(),
                  child: _buildCart()
                ),
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
            const SizedBox(height: 12),

            if (!_showNewCustomerForm) ...[
              // Show selected customer or search mode
              if (currentCustomer != null || _currentCustomerId != null) ...[
                // Selected Customer Display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade600),
                          const SizedBox(width: 8),
                          const Text(
                            "Customer Selected",
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              _clearCustomer();
                              setState(() {
                                _showNewCustomerForm = false;
                              });
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text("Change Customer"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nameController.text,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.directions_car, size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      plateController.text,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (_vehicleTypeForCustomer != null && _vehicleTypeForCustomer!.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _vehicleTypeForCustomer!,
                                          style: TextStyle(
                                            color: Colors.blue.shade700,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (emailController.text.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.email, size: 16, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                        emailController.text,
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (phoneController.text.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                        phoneController.text,
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Quick Search Mode
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: plateController,
                        decoration: InputDecoration(
                          labelText: "Search by Plate or Name",
                          hintText: "e.g. ABC1234 or John Doe (Press Enter to search)",
                          prefixIcon: Icon(Icons.search, color: Colors.blue.shade600),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          suffixIcon: plateController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    plateController.clear();
                                    nameController.clear();
                                    setState(() {
                                      _searchResults.clear();
                                      isSearching = false;
                                      _hasSearched = false;
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _hasSearched = false; // Reset when user types
                          });
                        },
                        onSubmitted: (value) {
                          final query = value.trim();
                          if (query.isNotEmpty) {
                            _performSearch(query);
                          }
                        },
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.search,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showNewCustomerForm = true;
                          _selectedVehicleType = null;
                          plateController.clear();
                          nameController.clear();
                          _searchResults.clear();
                          isSearching = false;
                          _hasSearched = false;
                        });
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text("New Customer"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ] else ...[
              // New Customer Form Mode
              Row(
                children: [
                  const Text(
                    "Adding New Customer",
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showNewCustomerForm = false;
                        _selectedVehicleType = null;
                        plateController.clear();
                        nameController.clear();
                        emailController.clear();
                        phoneController.clear();
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text("Back to Search"),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Plate Number Field (autofill trigger)
              TextField(
                controller: plateController,
                decoration: InputDecoration(
                  labelText: "Plate Number *",
                  hintText: "e.g. ABC1234",
                  prefixIcon: Icon(Icons.directions_car, color: Colors.blue.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),

              // Customer Name Field
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Customer Name *",
                  hintText: "e.g. John Doe",
                  prefixIcon: Icon(Icons.person, color: Colors.blue.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 12),

              // Email Field
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: "Email (Optional)",
                  hintText: "e.g. john@example.com",
                  prefixIcon: Icon(Icons.email, color: Colors.blue.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),

              // Contact Number Field
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: "Contact Number (Optional)",
                  hintText: "e.g. +63 912 345 6789",
                  prefixIcon: Icon(Icons.phone, color: Colors.blue.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),

              // Vehicle Type Field
              DropdownButtonFormField<String>(
                initialValue: _selectedVehicleType,
                decoration: InputDecoration(
                  labelText: "Vehicle Type (Optional)",
                  hintText: "Select vehicle type",
                  prefixIcon: Icon(Icons.directions_car, color: Colors.blue.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                items: _getVehicleTypeOptions().map((String vehicleType) {
                  return DropdownMenuItem<String>(
                    value: vehicleType,
                    child: Text(vehicleType),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedVehicleType = newValue;
                  });
                },
              ),
            ],
            const SizedBox(height: 16),

            // Loading indicator
            if (isSearching && !_showNewCustomerForm)
              Container(
                padding: const EdgeInsets.all(16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 12),
                    Text('Searching...'),
                  ],
                ),
              ),

            // Search Results
            if (searchResults.isNotEmpty && !_showNewCustomerForm && !isSearching)
              Container(
                height: _getSearchResultsMaxHeight(),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Found ${searchResults.length} customer${searchResults.length != 1 ? 's' : ''}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          if (searchResults.length > 2) ...[
                            const Spacer(),
                            Icon(
                              Icons.swipe_vertical,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Scroll',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: Scrollbar(
                        thumbVisibility: searchResults.length > 2,
                        thickness: 4,
                        radius: const Radius.circular(2),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          physics: const BouncingScrollPhysics(),
                          itemCount: searchResults.length,
                          itemBuilder: (context, index) {
                            final customer = searchResults[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  child: Icon(Icons.person, color: Colors.blue.shade700, size: 20),
                                ),
                                title: Text(
                                  customer.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.directions_car, size: 14, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(
                                          customer.plateNumber,
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (customer.vehicleType != null && customer.vehicleType!.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              customer.vehicleType!,
                                              style: TextStyle(
                                                color: Colors.green.shade700,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (customer.email.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.email, size: 12, color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              customer.email,
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.chevron_right, color: Colors.blue.shade600, size: 20),
                                ),
                                onTap: () => _selectCustomer(customer),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // No results message
            if (searchResults.isEmpty && !_showNewCustomerForm && !isSearching && _hasSearched && plateController.text.trim().isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'No customers found for "${plateController.text.trim()}"',
                      style: TextStyle(color: Colors.orange.shade700),
                    ),
                  ],
                ),
              ),

            if ((searchResults.isNotEmpty || isSearching) && !_showNewCustomerForm) const SizedBox(height: 16),

            // Service Time (always visible and separate from customer data)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    "Service Time: ${_formatTimeOfDay(context, _selectedTime)}",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text("Change"),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                      );
                      if (picked != null) {
                        setState(() => _selectedTime = picked);
                      }
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Save Customer Button (only in new customer form)
            if (_showNewCustomerForm) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveCustomer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow.shade700,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _currentCustomerId == null && (currentCustomer?.id == null)
                        ? "Save New Customer"
                        : "Update Customer",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
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
                          final navigator = Navigator.of(context);
                          final cash = double.tryParse(cashController.text) ?? 0;

                          for (final item in cart) {
                            final code = item["code"] as String;
                            final quantity = item["quantity"] as int;
                            await _consumeInventory(code, quantity);
                          }

                          if (mounted) {
                            navigator.pop();
                            _showTeamSelection(
                              cash: cash,
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

  /// SAVE TO FIRESTORE (Transactions + mirror Booking)
  Future<void> _saveTransactionToFirestore({
    required double cash,
    required double change,
    String? assignedTeam,
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

      // 👤 Customer (unified shape)
      final customerMap = {
        "id": _currentCustomerId ?? currentCustomer?.id,
        "plateNumber": plateController.text.trim().toUpperCase(),
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
        "contactNumber": phoneController.text.trim(),
        "vehicleType": _vehicleTypeForCustomer,
      };

      // 🧾 Services (unified name & fields)
      final services = cart.map((e) {
        final price = (e["price"] as num).toDouble();
        final qty = (e["quantity"] as int);
        return {
          "serviceCode": e["code"],
          "serviceName": _getServiceName(e["code"]),
          "vehicleType": e["category"],
          "price": price,
          "quantity": qty,
          "subtotal": price * qty,
        };
      }).toList();

      // 💵 Totals
      final double totalAmount = services.fold(
        0.0,
        (total, item) => total + (item["subtotal"] as double),
      );

      // 📘 Transactions collection (uses "services")
      final payload = {
        "customer": customerMap,
        "services": services, // 🔑 unified key
        "total": totalAmount,
        "cash": cash,
        "change": change,
        "date": Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
        "time": {
          "hour": _selectedTime.hour,
          "minute": _selectedTime.minute,
          "formatted": _formatTimeOfDay(context, _selectedTime),
        },
        "transactionAt": Timestamp.fromDate(txnDateTime),
        "status": "paid",
        "assignedTeam": assignedTeam ?? "Unassigned",
        "teamCommission": assignedTeam != null ? (totalAmount * 0.35) : 0.0, // 35% commission
        "createdAt": FieldValue.serverTimestamp(),
      };

      // Save transaction
      final transactionRef = await FirebaseFirestore.instance
          .collection("Transactions")
          .add(payload);

      // Create a corresponding approved booking (mirrors customer app schema)
      await _createBookingFromPOSTransaction(
        transactionId: transactionRef.id,
        txnDateTime: txnDateTime,
        customerMap: customerMap,
        services: services,
        totalAmount: totalAmount,
        assignedTeam: assignedTeam,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error saving transaction: $e")));
      }
    }
  }

  /// Mirror a booking entry (approved) so lists stay in sync with customer app
  Future<void> _createBookingFromPOSTransaction({
    required String transactionId,
    required DateTime txnDateTime,
    required Map<String, dynamic> customerMap,
    required List<Map<String, dynamic>> services,
    required double totalAmount,
    String? assignedTeam,
  }) async {
    try {
      // Follow the customer app booking structure:
      // - selectedDateTime (Timestamp)
      // - date (ISO)
      // - time (formatted string)
      // - services (same array)
      final bookingData = {
        "userId": customerMap["id"] ?? "",
        "userEmail": customerMap["email"] ?? "",
        "userName": customerMap["name"] ?? "",
        "plateNumber": customerMap["plateNumber"] ?? "",
        "contactNumber": customerMap["contactNumber"] ?? "",

        "selectedDateTime": Timestamp.fromDate(txnDateTime),
        "date": txnDateTime.toIso8601String(),
        "time": "${txnDateTime.hour.toString().padLeft(2, '0')}:${txnDateTime.minute.toString().padLeft(2, '0')}",

        "services": services, // 🔑 unified key
        "total": totalAmount,

        "status": "approved",
        "source": "pos",
        "transactionId": transactionId,
        "assignedTeam": assignedTeam ?? "Unassigned",
        "teamCommission": assignedTeam != null ? (totalAmount * 0.35) : 0.0, // 35% commission

        "createdAt": FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection("Bookings").add(bookingData);
    } catch (e) {
      debugPrint('Failed to create booking from POS transaction: $e');
    }
  }

  String _getServiceName(String serviceCode) {
    final service = servicesData[serviceCode];
    return service?['name'] ?? serviceCode;
  }

  List<String> _getVehicleTypeOptions() {
    // Extract vehicle types from all services
    final Set<String> vehicleTypes = {};
    for (final service in _services) {
      vehicleTypes.addAll(service.prices.keys);
    }
    return vehicleTypes.toList()..sort();
  }

  // Dynamic flex calculation for customer form
  int _getCustomerFormFlex() {
    // If searching and have results or in search mode, give more space to customer form
    if ((isSearching || searchResults.isNotEmpty || _hasSearched) && !_showNewCustomerForm) {
      return 4; // Expanded for search results
    }
    return 2; // Normal size
  }

  // Dynamic flex calculation for cart
  int _getCartFlex() {
    // If searching and have results or in search mode, shrink cart
    if ((isSearching || searchResults.isNotEmpty || _hasSearched) && !_showNewCustomerForm) {
      return 1; // Smaller during search
    }
    return 3; // Normal size
  }

  // Calculate max height for search results based on available space
  double _getSearchResultsMaxHeight() {
    // When customer form is expanded (flex: 4), we have more space
    if ((isSearching || searchResults.isNotEmpty || _hasSearched) && !_showNewCustomerForm) {
      // More space available - allow larger search results
      if (searchResults.length <= 2) {
        return searchResults.length * 90.0 + 60; // Individual item sizing
      } else {
        return 350; // Expanded max height for multiple results
      }
    }
    // Normal state - smaller max height
    if (searchResults.length <= 2) {
      return searchResults.length * 80.0 + 60;
    }
    return 220; // Original smaller max height
  }

  void _showTeamSelection({required double cash, required double change}) {
    String? selectedTeam;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing without selection
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.groups, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  const Text("Assign Team"),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Which team will handle this service?",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              selectedTeam = "Team A";
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selectedTeam == "Team A"
                                  ? Colors.blue.shade100
                                  : Colors.grey.shade100,
                              border: Border.all(
                                color: selectedTeam == "Team A"
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade300,
                                width: selectedTeam == "Team A" ? 3 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.group,
                                  size: 40,
                                  color: selectedTeam == "Team A"
                                      ? Colors.blue.shade600
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Team A",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: selectedTeam == "Team A"
                                        ? Colors.blue.shade600
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              selectedTeam = "Team B";
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selectedTeam == "Team B"
                                  ? Colors.green.shade100
                                  : Colors.grey.shade100,
                              border: Border.all(
                                color: selectedTeam == "Team B"
                                    ? Colors.green.shade600
                                    : Colors.grey.shade300,
                                width: selectedTeam == "Team B" ? 3 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.group,
                                  size: 40,
                                  color: selectedTeam == "Team B"
                                      ? Colors.green.shade600
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Team B",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: selectedTeam == "Team B"
                                        ? Colors.green.shade600
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: selectedTeam != null
                      ? () async {
                          final navigator = Navigator.of(context);
                          final team = selectedTeam!;

                          await _saveTransactionToFirestore(
                            cash: cash,
                            change: change,
                            assignedTeam: team,
                          );

                          if (mounted) {
                            navigator.pop();
                            _showReceipt(
                              cash: cash,
                              change: change,
                              assignedTeam: team,
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text("Confirm Assignment"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReceipt({required double cash, required double change, String? assignedTeam}) {
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
                if (assignedTeam != null) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  Text(
                    "Assigned Team: $assignedTeam",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
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
