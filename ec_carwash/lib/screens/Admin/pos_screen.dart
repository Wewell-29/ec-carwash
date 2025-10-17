import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ec_carwash/data_models/services_data.dart';
import 'package:ec_carwash/data_models/inventory_data.dart';
import 'package:ec_carwash/data_models/customer_data_unified.dart';
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

    // Get the service name from servicesData
    final serviceName = servicesData[code]?["name"] ?? code;

    final index = cart.indexWhere(
      (item) => item["code"] == code && item["category"] == category,
    );

    if (index >= 0) {
      // Already in cart - increase quantity and show notification
      setState(() {
        cart[index]["quantity"] = (cart[index]["quantity"] ?? 0) + 1;
      });

      if (mounted) {
        final currentQty = cart[index]["quantity"] as int;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('$serviceName already in cart! Quantity increased to $currentQty'),
                ),
              ],
            ),
            backgroundColor: Colors.yellow.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      // New item - add to cart
      setState(() {
        cart.add({
          "code": code,
          "name": serviceName,
          "category": category,
          "price": price.toDouble(),
          "quantity": 1,
        });
      });
    }
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
        final customer = await CustomerManager.getCustomerByPlateNumber(query);
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
            final customers = await CustomerManager.searchCustomersByName(variation);
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
      'contactNumber': base.contactNumber,
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
        contactNumber: phoneController.text.trim(),
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
                Color color = Colors.yellow.shade700;

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
    // Notification removed as requested
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingServices) {
      return const Center(child: CircularProgressIndicator());
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 700;
    final isTablet = screenWidth > 600 && screenWidth <= 1024; // iPad mini range
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
          flex: isTablet ? 3 : 4, // Reduce grid space for tablets
          child: GridView.builder(
            padding: EdgeInsets.all(isTablet ? 8 : 16), // Smaller padding for tablets
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isTablet
                  ? 3  // Fewer columns for tablets to prevent overflow
                  : screenWidth > 1400
                  ? 6
                  : screenWidth > 1200
                  ? 5
                  : 4,
              childAspectRatio: isTablet ? 0.9 : 0.85, // Slightly taller cards for tablets
              crossAxisSpacing: isTablet ? 6 : 8,
              mainAxisSpacing: isTablet ? 6 : 8,
            ),
            itemCount: codes.length,
            itemBuilder: (context, index) {
              final code = codes[index];
              final product = servicesData[code];
              if (product == null) return const SizedBox();

              // Check if service is applicable for current vehicle type
              final prices = product["prices"] as Map<String, dynamic>;
              final bool isApplicable = _vehicleTypeForCustomer == null ||
                                       _vehicleTypeForCustomer!.isEmpty ||
                                       prices.containsKey(_vehicleTypeForCustomer);

              return Opacity(
                opacity: isApplicable ? 1.0 : 0.4,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: isApplicable ? () => _handleAddService(code) : null,
                    splashColor: isApplicable ? Colors.yellow.shade200 : null,
                    highlightColor: isApplicable ? Colors.yellow.shade100 : null,
                    child: Container(
                    decoration: BoxDecoration(
                      // Modern gradient with brand colors
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Colors.yellow.shade50,
                          Colors.white,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      // Thin black stroke as requested
                      border: Border.all(
                        color: Colors.black87,
                        width: 1.0,
                      ),
                      // Enhanced shadow for depth
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isTablet ? 8.0 : 12.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Service code chip with brand styling
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 10 : 12,
                              vertical: isTablet ? 6 : 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.yellow.shade700,
                                  Colors.yellow.shade800,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.black54,
                                width: 0.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              _getDisplayCode(code, isTablet),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isTablet ? 16 : 18,
                                color: Colors.black87,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          SizedBox(height: isTablet ? 6 : 8),
                          // Service name with better typography
                          Expanded(
                            child: Center(
                              child: Text(
                                product["name"],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isTablet ? 11 : 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                  height: 1.2,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          // Add a subtle price indicator at the bottom
                          Container(
                            width: double.infinity,
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.yellow.shade600,
                                  Colors.yellow.shade400,
                                  Colors.yellow.shade600,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
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
            flex: isTablet ? 3 : 2, // Increase side panel space for tablets
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600 && screenWidth <= 1024;

    return Container(
      padding: EdgeInsets.all(isTablet ? 12 : 16), // Smaller padding for tablets
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  "Customer Information",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isTablet ? 16 : 18,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
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
                  padding: EdgeInsets.all(isTablet ? 12 : 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.green.shade50,
                        Colors.white,
                        Colors.green.shade50,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black87, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
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
                                          color: Colors.yellow.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _vehicleTypeForCustomer!,
                                          style: TextStyle(
                                            color: Colors.black87,
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
                          prefixIcon: Icon(Icons.search, color: Colors.black87),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.yellow.shade700, width: 2),
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
                  prefixIcon: Icon(Icons.directions_car, color: Colors.black87),
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
                  prefixIcon: Icon(Icons.person, color: Colors.black87),
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
                  prefixIcon: Icon(Icons.email, color: Colors.black87),
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
                  prefixIcon: Icon(Icons.phone, color: Colors.black87),
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
                  prefixIcon: Icon(Icons.directions_car, color: Colors.black87),
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
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.yellow.shade50,
                      Colors.white,
                    ],
                  ),
                  border: Border.all(color: Colors.black87, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
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
              padding: EdgeInsets.all(isTablet ? 10 : 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.yellow.shade50, Colors.white],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black87, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.yellow.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
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
                        // Prevent selecting past time
                        final now = DateTime.now();
                        final selectedDateTime = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          picked.hour,
                          picked.minute,
                        );

                        // Check if selected time is in the past
                        if (selectedDateTime.isBefore(now)) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Cannot select past time'),
                                backgroundColor: Colors.red.shade700,
                              ),
                            );
                          }
                          return;
                        }

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600 && screenWidth <= 1024;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.yellow.shade50,
            Colors.white,
          ],
        ),
        border: Border.all(color: Colors.black87, width: 1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cart header with theme styling
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isTablet ? 12 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.yellow.shade700, Colors.yellow.shade800],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.black54, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shopping_cart,
                  color: Colors.black87,
                  size: isTablet ? 20 : 24,
                ),
                const SizedBox(width: 8),
                Text(
                  "Cart",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isTablet ? 16 : 18,
                    color: Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                if (cart.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${cart.length}',
                      style: TextStyle(
                        color: Colors.yellow.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: isTablet ? 12 : 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Cart content
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: isTablet ? 48 : 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "No items in cart",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: isTablet ? 14 : 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(isTablet ? 8 : 12),
                    itemCount: cart.length,
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      final price = (item["price"] as num).toDouble();
                      final qty = (item["quantity"] ?? 0) as int;
                      final subtotal = price * qty;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.black26, width: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 12 : 16,
                            vertical: isTablet ? 4 : 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.yellow.shade600, Colors.yellow.shade700],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.black54, width: 0.5),
                            ),
                            child: Text(
                              _getDisplayCode(item["code"], isTablet),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isTablet ? 10 : 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          title: Text(
                            item["category"],
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: isTablet ? 13 : 14,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          subtitle: Text(
                            "₱${price.toStringAsFixed(2)} x $qty = ₱${subtotal.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: isTablet ? 11 : 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: Container(
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.red.shade200, width: 0.5),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red.shade600,
                                size: isTablet ? 20 : 24,
                              ),
                              onPressed: () => removeFromCart(index),
                              padding: EdgeInsets.all(isTablet ? 4 : 8),
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Cart footer with total and checkout
          Container(
            padding: EdgeInsets.all(isTablet ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.black26, width: 0.5),
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(11),
                bottomRight: Radius.circular(11),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isTablet ? 16 : 18,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    Text(
                      "₱${total.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isTablet ? 18 : 20,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: cart.isEmpty ? null : _showCartSummary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cart.isEmpty ? Colors.grey.shade300 : Colors.yellow.shade700,
                      foregroundColor: cart.isEmpty ? Colors.grey.shade600 : Colors.black87,
                      padding: EdgeInsets.symmetric(vertical: isTablet ? 12 : 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: cart.isEmpty ? Colors.grey.shade400 : Colors.black54,
                          width: 0.5,
                        ),
                      ),
                      elevation: cart.isEmpty ? 0 : 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.payment,
                          size: isTablet ? 18 : 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Checkout",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isTablet ? 14 : 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
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
            return Dialog(
              insetPadding: const EdgeInsets.all(40),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.7,
                height: MediaQuery.of(context).size.height * 0.6,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black87, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(Icons.receipt_long, size: 32, color: Colors.yellow.shade700),
                        const SizedBox(width: 12),
                        Text(
                          "Order Summary",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, size: 28),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey.shade100,
                            foregroundColor: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Information Section
                    if (nameController.text.trim().isNotEmpty || plateController.text.trim().isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade50, Colors.blue.shade100],
                          ),
                          border: Border.all(color: Colors.blue.shade300, width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person, color: Theme.of(context).colorScheme.primary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  "Customer Information",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (nameController.text.trim().isNotEmpty)
                              Text(
                                "Name: ${nameController.text.trim()}",
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                            if (plateController.text.trim().isNotEmpty)
                              Text(
                                "Plate: ${plateController.text.trim().toUpperCase()}",
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Services Section
                    Text(
                      "Services:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...cart.map((item) {
                      final price = (item["price"] as num).toDouble();
                      final qty = (item["quantity"] ?? 0) as int;
                      final subtotal = price * qty;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${item["code"]} - ${item["category"]}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "₱${price.toStringAsFixed(2)} x $qty = ₱${subtotal.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(thickness: 2),
                    Text(
                      "Total: ₱${total.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: cashController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        labelText: "Cash Amount",
                        labelStyle: const TextStyle(fontSize: 15),
                        border: const OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.yellow.shade700, width: 2),
                        ),
                        prefixIcon: Icon(Icons.payments, color: Colors.green.shade600),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      onChanged: (val) {
                        final cash = double.tryParse(val) ?? 0;
                        setState(() {
                          change = cash - total;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: change >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                        border: Border.all(
                          color: change >= 0 ? Colors.green.shade300 : Colors.red.shade300,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Change:",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            "₱${change.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: change >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Footer with buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.shade600, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: change < 0 ? Colors.grey.shade300 : Colors.yellow.shade700,
                      foregroundColor: change < 0 ? Colors.grey.shade600 : Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: change < 0 ? Colors.grey.shade400 : Colors.black54,
                          width: 1,
                        ),
                      ),
                      elevation: change < 0 ? 0 : 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payment, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          "Proceed to Payment",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
        "teamCommission": 0.0, // Commission added only when booking is marked completed
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

      // Clear cart and reset customer after successful transaction
      if (mounted) {
        setState(() {
          cart.clear();
          currentCustomer = null;
          _currentCustomerId = null;
          _vehicleTypeForCustomer = null;
          _selectedVehicleType = null;
          nameController.clear();
          plateController.clear();
          phoneController.clear();
          emailController.clear();
        });
      }
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
      // Use unified booking structure with scheduledDateTime (not selectedDateTime)
      final bookingData = {
        "userId": customerMap["id"] ?? "",
        "userEmail": customerMap["email"] ?? "",
        "userName": customerMap["name"] ?? "",
        "plateNumber": customerMap["plateNumber"] ?? "",
        "contactNumber": customerMap["contactNumber"] ?? "",
        "vehicleType": customerMap["vehicleType"],

        // 🔑 UNIFIED FIELD: scheduledDateTime (for Firestore queries to work)
        "scheduledDateTime": Timestamp.fromDate(txnDateTime),

        "services": services, // 🔑 unified key
        "totalAmount": totalAmount, // Use totalAmount for consistency

        "status": "approved",
        "paymentStatus": "paid", // POS transactions are already paid
        "source": "pos",
        "transactionId": transactionId,
        "assignedTeam": assignedTeam ?? "Unassigned",
        "teamCommission": 0.0, // Commission added only when booking is marked completed

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

  String _getDisplayCode(String code, bool isSmallScreen) {
    if (!isSmallScreen) return code;

    // Shorten PROMO codes to PR + number
    if (code.startsWith('PROMO')) {
      final number = code.replaceAll(RegExp(r'[^0-9]'), '');
      return 'PR$number';
    }

    // Shorten UPGRADE codes to UP + number
    if (code.startsWith('UPGRADE')) {
      final number = code.replaceAll(RegExp(r'[^0-9]'), '');
      return 'UP$number';
    }

    return code; // Keep EC codes and others as-is
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
            return Dialog(
              insetPadding: const EdgeInsets.all(40),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.6,
                height: MediaQuery.of(context).size.height * 0.5,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black87, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.groups, size: 40, color: Colors.blue.shade600),
                        const SizedBox(width: 12),
                        Text(
                          "Assign Team",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Which team will handle this service?",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    // Content
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  selectedTeam = "Team A";
                                });
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                height: 200,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: selectedTeam == "Team A"
                                      ? LinearGradient(colors: [Colors.blue.shade100, Colors.blue.shade50])
                                      : LinearGradient(colors: [Colors.grey.shade100, Colors.white]),
                                  border: Border.all(
                                    color: selectedTeam == "Team A"
                                        ? Colors.black87
                                        : Colors.grey.shade400,
                                    width: selectedTeam == "Team A" ? 3 : 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: selectedTeam == "Team A"
                                          ? Colors.blue.withValues(alpha: 0.3)
                                          : Colors.black.withValues(alpha: 0.1),
                                      blurRadius: selectedTeam == "Team A" ? 12 : 6,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.group,
                                      size: 64,
                                      color: selectedTeam == "Team A"
                                          ? Colors.blue.shade600
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      "Team A",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 24,
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
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                height: 200,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: selectedTeam == "Team B"
                                      ? LinearGradient(colors: [Colors.green.shade100, Colors.green.shade50])
                                      : LinearGradient(colors: [Colors.grey.shade100, Colors.white]),
                                  border: Border.all(
                                    color: selectedTeam == "Team B"
                                        ? Colors.black87
                                        : Colors.grey.shade400,
                                    width: selectedTeam == "Team B" ? 3 : 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: selectedTeam == "Team B"
                                          ? Colors.green.withValues(alpha: 0.3)
                                          : Colors.black.withValues(alpha: 0.1),
                                      blurRadius: selectedTeam == "Team B" ? 12 : 6,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.group,
                                      size: 64,
                                      color: selectedTeam == "Team B"
                                          ? Colors.green.shade600
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      "Team B",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 24,
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
                    ),
                    const SizedBox(height: 32),
                    // Actions Row
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selectedTeam != null
                                ? () async {
                                    final navigator = Navigator.of(context);
                                    final team = selectedTeam!;

                                    // Save cart data before clearing
                                    final cartSnapshot = List<Map<String, dynamic>>.from(cart);
                                    final totalSnapshot = total;

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
                                        cartItems: cartSnapshot,
                                        total: totalSnapshot,
                                      );
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedTeam != null ? Colors.yellow.shade700 : Colors.grey.shade300,
                              foregroundColor: selectedTeam != null ? Colors.black87 : Colors.grey.shade600,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: selectedTeam != null ? Colors.black54 : Colors.grey.shade400,
                                  width: 1,
                                ),
                              ),
                              elevation: selectedTeam != null ? 4 : 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, size: 24),
                                const SizedBox(width: 8),
                                const Text(
                                  "Confirm Assignment",
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showReceipt({
    required double cash,
    required double change,
    String? assignedTeam,
    required List<Map<String, dynamic>> cartItems,
    required double total,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(40),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.75,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black87, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.receipt_long, size: 40, color: Colors.green.shade600),
                    const SizedBox(width: 12),
                    Text(
                      "Transaction Receipt",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      iconSize: 32,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Transaction Details Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.grey.shade50, Colors.grey.shade100],
                            ),
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Transaction Details",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Date: ${DateTime.now().toString().substring(0, 10)}",
                                style: const TextStyle(fontSize: 16),
                              ),
                              Text(
                                "Time: ${_formatTimeOfDay(context, _selectedTime)}",
                                style: const TextStyle(fontSize: 16),
                              ),
                              if (assignedTeam != null)
                                Text(
                                  "Assigned Team: $assignedTeam",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Services List
                        Text(
                          "Services",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...cartItems.map((item) {
                          final price = (item["price"] as num).toDouble();
                          final qty = (item["quantity"] ?? 0) as int;
                          final subtotal = price * qty;
                          final serviceName = item["name"]?.toString() ?? item["code"]?.toString() ?? "";
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              border: Border.all(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        serviceName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        "${item["category"]}",
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    "Qty: $qty",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    "₱${price.toStringAsFixed(2)}",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    "₱${subtotal.toStringAsFixed(2)}",
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                        // Payment Summary
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.green.shade50, Colors.green.shade100],
                            ),
                            border: Border.all(color: Colors.green.shade300, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "Payment Summary",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Total:", style: TextStyle(fontSize: 18)),
                                  Text(
                                    "₱${total.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Cash:", style: TextStyle(fontSize: 18)),
                                  Text(
                                    "₱${cash.toStringAsFixed(2)}",
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Change:", style: TextStyle(fontSize: 18)),
                                  Text(
                                    "₱${change.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.grey.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade400),
                          ),
                        ),
                        child: const Text(
                          "Close",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            final pdf = pw.Document();

                            // Generate transaction ID
                            final transactionId = 'TXN${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
                            final now = DateTime.now();
                            final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
                            final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

                            // Try to load fonts, fallback to default
                            pw.Font? regularFont;
                            pw.Font? boldFont;
                            try {
                              regularFont = pw.Font.ttf(await rootBundle.load("assets/fonts/Roboto-Regular.ttf"));
                              boldFont = pw.Font.ttf(await rootBundle.load("assets/fonts/Roboto-Bold.ttf"));
                            } catch (e) {
                              debugPrint('Using default fonts: $e');
                            }

                            // Thermal receipt style - 80mm width (226.77 points)
                            pdf.addPage(
                              pw.Page(
                                pageFormat: const PdfPageFormat(226.77, double.infinity, marginAll: 10),
                                build: (pw.Context ctx) {
                                  return pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                                    children: [
                                      // Header - Business Name
                                      pw.Text(
                                        "EC CARWASH",
                                        style: pw.TextStyle(
                                          font: boldFont,
                                          fontSize: 16,
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                      ),
                                      pw.SizedBox(height: 2),
                                      pw.Text(
                                        "Balayan Batangas",
                                        style: pw.TextStyle(
                                          font: regularFont,
                                          fontSize: 8,
                                        ),
                                      ),
                                      pw.SizedBox(height: 4),
                                      pw.Text(
                                        "SALES INVOICE",
                                        style: pw.TextStyle(
                                          font: boldFont,
                                          fontSize: 10,
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                      ),
                                      pw.SizedBox(height: 8),

                                      // Divider
                                      pw.Divider(thickness: 1),

                                      // Transaction Info
                                      pw.Container(
                                        width: double.infinity,
                                        child: pw.Column(
                                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                                          children: [
                                            _receiptRow("TXN ID:", transactionId, boldFont),
                                            _receiptRow("Date:", dateStr, regularFont),
                                            _receiptRow("Time:", timeStr, regularFont),
                                            if (currentCustomer != null) ...[
                                              pw.SizedBox(height: 4),
                                              _receiptRow("Customer:", currentCustomer!.name, regularFont),
                                              _receiptRow("Plate No:", currentCustomer!.plateNumber, regularFont),
                                              if (currentCustomer!.contactNumber.isNotEmpty)
                                                _receiptRow("Contact:", currentCustomer!.contactNumber, regularFont),
                                              if (_vehicleTypeForCustomer != null && _vehicleTypeForCustomer!.isNotEmpty)
                                                _receiptRow("Vehicle:", _vehicleTypeForCustomer!, regularFont),
                                            ],
                                            if (assignedTeam != null)
                                              _receiptRow("Team:", assignedTeam, regularFont),
                                          ],
                                        ),
                                      ),

                                      pw.Divider(thickness: 1),

                                      // Items header
                                      pw.Container(
                                        width: double.infinity,
                                        child: pw.Row(
                                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                          children: [
                                            pw.Expanded(
                                              flex: 3,
                                              child: pw.Text(
                                                "ITEM",
                                                style: pw.TextStyle(
                                                  font: boldFont,
                                                  fontSize: 8,
                                                  fontWeight: pw.FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            pw.Container(
                                              width: 25,
                                              child: pw.Text(
                                                "QTY",
                                                style: pw.TextStyle(
                                                  font: boldFont,
                                                  fontSize: 8,
                                                  fontWeight: pw.FontWeight.bold,
                                                ),
                                                textAlign: pw.TextAlign.center,
                                              ),
                                            ),
                                            pw.Container(
                                              width: 45,
                                              child: pw.Text(
                                                "PRICE",
                                                style: pw.TextStyle(
                                                  font: boldFont,
                                                  fontSize: 8,
                                                  fontWeight: pw.FontWeight.bold,
                                                ),
                                                textAlign: pw.TextAlign.right,
                                              ),
                                            ),
                                            pw.Container(
                                              width: 50,
                                              child: pw.Text(
                                                "AMOUNT",
                                                style: pw.TextStyle(
                                                  font: boldFont,
                                                  fontSize: 8,
                                                  fontWeight: pw.FontWeight.bold,
                                                ),
                                                textAlign: pw.TextAlign.right,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      pw.Container(
                                        width: double.infinity,
                                        height: 0.5,
                                        color: PdfColors.black,
                                      ),

                                      // Items
                                      ...cartItems.map((item) {
                                        final price = (item["price"] as num).toDouble();
                                        final qty = (item["quantity"] ?? 0) as int;
                                        final subtotal = price * qty;
                                        final serviceName = item["name"]?.toString() ?? item["code"]?.toString() ?? "";
                                        final serviceCategory = item["category"]?.toString() ?? "";
                                        return pw.Column(
                                          children: [
                                            pw.SizedBox(height: 4),
                                            pw.Container(
                                              width: double.infinity,
                                              child: pw.Column(
                                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                                children: [
                                                  // Service name
                                                  pw.Text(
                                                    serviceName,
                                                    style: pw.TextStyle(
                                                      font: boldFont,
                                                      fontSize: 9,
                                                      fontWeight: pw.FontWeight.bold,
                                                    ),
                                                  ),
                                                  pw.SizedBox(height: 2),
                                                  // Price row with qty, price, amount
                                                  pw.Row(
                                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      pw.Text(
                                                        "  $serviceCategory",
                                                        style: pw.TextStyle(
                                                          font: regularFont,
                                                          fontSize: 7,
                                                          color: PdfColors.grey700,
                                                        ),
                                                      ),
                                                      pw.Row(
                                                        children: [
                                                          pw.Container(
                                                            width: 25,
                                                            child: pw.Text(
                                                              "$qty",
                                                              style: pw.TextStyle(
                                                                font: regularFont,
                                                                fontSize: 9,
                                                              ),
                                                              textAlign: pw.TextAlign.center,
                                                            ),
                                                          ),
                                                          pw.Container(
                                                            width: 45,
                                                            child: pw.Text(
                                                              "P${price.toStringAsFixed(2)}",
                                                              style: pw.TextStyle(
                                                                font: regularFont,
                                                                fontSize: 9,
                                                              ),
                                                              textAlign: pw.TextAlign.right,
                                                            ),
                                                          ),
                                                          pw.Container(
                                                            width: 50,
                                                            child: pw.Text(
                                                              "P${subtotal.toStringAsFixed(2)}",
                                                              style: pw.TextStyle(
                                                                font: regularFont,
                                                                fontSize: 9,
                                                              ),
                                                              textAlign: pw.TextAlign.right,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            pw.SizedBox(height: 4),
                                          ],
                                        );
                                      }),

                                      pw.Divider(thickness: 1),

                                      // Totals
                                      pw.Container(
                                        width: double.infinity,
                                        child: pw.Column(
                                          children: [
                                            pw.Row(
                                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                              children: [
                                                pw.Text(
                                                  "SUBTOTAL:",
                                                  style: pw.TextStyle(
                                                    font: regularFont,
                                                    fontSize: 9,
                                                  ),
                                                ),
                                                pw.Text(
                                                  "P${total.toStringAsFixed(2)}",
                                                  style: pw.TextStyle(
                                                    font: regularFont,
                                                    fontSize: 9,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            pw.SizedBox(height: 2),
                                            pw.Row(
                                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                              children: [
                                                pw.Text(
                                                  "TOTAL:",
                                                  style: pw.TextStyle(
                                                    font: boldFont,
                                                    fontSize: 12,
                                                    fontWeight: pw.FontWeight.bold,
                                                  ),
                                                ),
                                                pw.Text(
                                                  "P${total.toStringAsFixed(2)}",
                                                  style: pw.TextStyle(
                                                    font: boldFont,
                                                    fontSize: 12,
                                                    fontWeight: pw.FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            pw.SizedBox(height: 4),
                                            pw.Row(
                                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                              children: [
                                                pw.Text(
                                                  "Cash:",
                                                  style: pw.TextStyle(
                                                    font: regularFont,
                                                    fontSize: 9,
                                                  ),
                                                ),
                                                pw.Text(
                                                  "P${cash.toStringAsFixed(2)}",
                                                  style: pw.TextStyle(
                                                    font: regularFont,
                                                    fontSize: 9,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            pw.SizedBox(height: 2),
                                            pw.Row(
                                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                              children: [
                                                pw.Text(
                                                  "Change:",
                                                  style: pw.TextStyle(
                                                    font: regularFont,
                                                    fontSize: 9,
                                                  ),
                                                ),
                                                pw.Text(
                                                  "P${change.toStringAsFixed(2)}",
                                                  style: pw.TextStyle(
                                                    font: regularFont,
                                                    fontSize: 9,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      pw.Divider(thickness: 1),

                                      // Footer
                                      pw.SizedBox(height: 4),
                                      pw.Text(
                                        "THANK YOU FOR YOUR BUSINESS!",
                                        style: pw.TextStyle(
                                          font: boldFont,
                                          fontSize: 8,
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                        textAlign: pw.TextAlign.center,
                                      ),
                                      pw.SizedBox(height: 2),
                                      pw.Text(
                                        "Please come again",
                                        style: pw.TextStyle(
                                          font: regularFont,
                                          fontSize: 7,
                                        ),
                                        textAlign: pw.TextAlign.center,
                                      ),
                                      pw.SizedBox(height: 8),
                                      pw.Text(
                                        "This serves as your official receipt",
                                        style: pw.TextStyle(
                                          font: regularFont,
                                          fontSize: 6,
                                          fontStyle: pw.FontStyle.italic,
                                        ),
                                        textAlign: pw.TextAlign.center,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            );

                            await Printing.sharePdf(
                              bytes: await pdf.save(),
                              filename: "receipt_$transactionId.pdf",
                            );

                            if (mounted) {
                              setState(() => cart.clear());
                              if (context.mounted) Navigator.pop(context);
                            }
                          } catch (e) {
                            debugPrint('Error generating receipt: $e');
                            if (mounted && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error generating receipt: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellow.shade700,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.black54),
                          ),
                          elevation: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.print, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              "Print as PDF",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Helper for thermal receipt row
pw.Widget _receiptRow(String label, String value, pw.Font? font) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(
          font: font,
          fontSize: 8,
        ),
      ),
      pw.Text(
        value,
        style: pw.TextStyle(
          font: font,
          fontSize: 8,
        ),
      ),
    ],
  );
}
