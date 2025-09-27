import 'package:flutter/material.dart';
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

  // Controllers for customer form
  final TextEditingController nameController = TextEditingController();
  final TextEditingController plateController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

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
    // Ensure searchResults is properly initialized
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
      print('Error loading services: $e');
    }
  }

  // Convert Firebase services to the format expected by POS
  Map<String, Map<String, dynamic>> get servicesData {
    final Map<String, Map<String, dynamic>> data = {};
    for (final service in _services) {
      data[service.code] = {
        'name': service.name,
        'prices': service.prices,
      };
    }
    return data;
  }


  // Only map accessories/add-ons to inventory, not main car wash services
  // Main services (EC1-EC8, etc.) are always available and don't consume inventory
  // Services use inventory items but availability isn't restricted by stock
  final Map<String, String> serviceToInventoryMap = {
    // Services consume these inventory items but are always available
    'EC1': 'INV001', // Basic wash uses Car Shampoo
    'EC2': 'INV003', // Premium wash uses Armor All Spray Wax
    'EC3': 'INV004', // Deluxe wash uses Hand Wax
    'EC4': 'INV005', // Polish service uses Polishing Compound
    'EC6': 'INV011', // Interior cleaning uses Interior Cleaner
    'EC7': 'INV007', // Engine cleaning uses Engine Degreaser
    'EC9': 'INV006', // Window service uses Glass Cleaner
    'EC14': 'INV006', // Headlight restoration uses Glass Cleaner
  };

  double get total => cart.fold(0.0, (sum, item) {
    final price = (item["price"] ?? 0) as num;
    final qty = (item["quantity"] ?? 0) as int;
    return sum + price.toDouble() * qty;
  });

  Future<bool> _checkInventoryAvailability(String code) async {
    // All services are always available regardless of inventory stock
    // This is because services are the main business offering
    // Inventory consumption happens after service completion
    return true;
  }

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
          SnackBar(
            content: Text('Insufficient inventory for service $code'),
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
      nameController.clear();
      plateController.clear();
      emailController.clear();
      phoneController.clear();
      _searchResults.clear();
    });
  }

  void _searchByPlate(String plateNumber) async {
    if (plateNumber.length >= 3) {
      setState(() => isSearching = true);
      try {
        final customer = await CustomerService.getCustomerByPlateNumber(plateNumber);
        if (customer != null) {
          _selectCustomer(customer);
        } else {
          setState(() {
            _searchResults.clear();
            isSearching = false;
          });
        }
      } catch (e) {
        setState(() => isSearching = false);
      }
    }
  }

  void _searchByName(String name) async {
    if (name.length >= 2) {
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

  void _selectCustomer(Customer customer) {
    setState(() {
      currentCustomer = customer;
      nameController.text = customer.name;
      plateController.text = customer.plateNumber;
      emailController.text = customer.email;
      phoneController.text = customer.phoneNumber;
      _searchResults.clear();
    });
  }

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
      final customer = Customer(
        id: currentCustomer?.id,
        name: nameController.text,
        plateNumber: plateController.text,
        email: emailController.text,
        phoneNumber: phoneController.text,
        createdAt: currentCustomer?.createdAt ?? DateTime.now(),
        lastVisit: DateTime.now(),
      );

      final customerId = await CustomerService.saveCustomer(customer);
      setState(() {
        currentCustomer = customer.copyWith(id: customerId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving customer: $e')),
        );
      }
    }
  }

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
                final price = entry.value;
                IconData icon = Icons.directions_car;
                Color color = Colors.blue;

                // Set icons based on vehicle type
                if (vehicleType.contains('Motorcycle')) {
                  icon = Icons.motorcycle;
                  color = Colors.green;
                } else if (vehicleType.contains('Truck')) {
                  icon = Icons.local_shipping;
                  color = Colors.red;
                } else if (vehicleType.contains('Van') || vehicleType.contains('SUV')) {
                  icon = Icons.airport_shuttle;
                  color = Colors.orange;
                } else if (vehicleType.contains('Tricycle')) {
                  icon = Icons.pedal_bike;
                  color = Colors.purple;
                }

                return ListTile(
                  leading: Icon(icon, color: color),
                  title: Text(vehicleType),
                  subtitle: Text('₱${price.toString()}'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _addSingleCodeToCart(code, vehicleType, price.toDouble());
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _addSingleCodeToCart(String code, String category, double price) async {
    await addToCart(code, category, price);

    // Show success message
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

    // Sort codes in proper order: EC1-15, UPGRADE1-4, PROMO1-4
    codes.sort((a, b) {
      // Helper function to get sort priority
      int getSortPriority(String code) {
        if (code.startsWith('EC')) return 1;
        if (code.startsWith('UPGRADE')) return 2;
        if (code.startsWith('PROMO')) return 3;
        return 4;
      }

      // Helper function to extract number from code
      int getCodeNumber(String code) {
        final numStr = code.replaceAll(RegExp(r'[^0-9]'), '');
        return int.tryParse(numStr) ?? 0;
      }

      final priorityA = getSortPriority(a);
      final priorityB = getSortPriority(b);

      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }

      // Within same category, sort by number
      return getCodeNumber(a).compareTo(getCodeNumber(b));
    });

    return Row(
        children: [
          /// Product Codes Grid
          Expanded(
            flex: 4,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 1400 ? 6 :
                               MediaQuery.of(context).size.width > 1200 ? 5 : 4,
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
                    onTap: () {
                      // Show vehicle type selection dialog immediately
                      _showVehicleTypeDialog(code);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            Color(0xFFF8F9FA),
                            Colors.white,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
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

          /// Product Details + Cart (side panel on wide screen)
          if (isWide)
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildCustomerForm(),
                  ),
                  Expanded(
                    flex: 3,
                    child: _buildCart(),
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
              if (currentCustomer != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _clearCustomer(),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Plate Number Field
          TextField(
            controller: plateController,
            decoration: const InputDecoration(
              labelText: "Plate Number",
              prefixIcon: Icon(Icons.directions_car),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => _searchByPlate(value),
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
            onChanged: (value) => _searchByName(value),
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

          // Phone Field
          TextField(
            controller: phoneController,
            decoration: const InputDecoration(
              labelText: "Phone Number",
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

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

          // Quick Service Selection Info
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
                    "Tap any service card to add it directly to cart",
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
              child: Text(currentCustomer == null ? "Save New Customer" : "Update Customer"),
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
                  onPressed: cart.isEmpty ? null : () => _showCartSummary(),
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
                    // List of services
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

                    // Totals
                    Text(
                      "Total: ₱${total.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Cash input
                    TextField(
                      controller: cashController,
                      keyboardType: TextInputType.number,
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

                // ✅ Load embedded fonts
                final robotoRegular = pw.Font.ttf(
                  await rootBundle.load("Roboto-Regular.ttf"),
                );
                final robotoBold = pw.Font.ttf(
                  await rootBundle.load("Roboto-Bold.ttf"),
                );

                pdf.addPage(
                  pw.Page(
                    build: (pw.Context context) {
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
                            pw.SizedBox(height: 10),

                            // 🧾 Table for items
                            pw.Table(
                              border: pw.TableBorder.all(width: 0.5),
                              columnWidths: {
                                0: const pw.FlexColumnWidth(2), // Service
                                1: const pw.FlexColumnWidth(1), // Qty
                                2: const pw.FlexColumnWidth(1), // Price
                                3: const pw.FlexColumnWidth(1.5), // Subtotal
                              },
                              children: [
                                // Header row
                                pw.TableRow(
                                  decoration: const pw.BoxDecoration(
                                    color: PdfColors.grey300,
                                  ),
                                  children: [
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.all(4),
                                      child: pw.Text(
                                        "Service",
                                        style: pw.TextStyle(
                                          font: robotoBold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.all(4),
                                      child: pw.Text(
                                        "Qty",
                                        style: pw.TextStyle(
                                          font: robotoBold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.all(4),
                                      child: pw.Text(
                                        "Price",
                                        style: pw.TextStyle(
                                          font: robotoBold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.all(4),
                                      child: pw.Text(
                                        "Subtotal",
                                        style: pw.TextStyle(
                                          font: robotoBold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Item rows
                                ...cart.map((item) {
                                  final price = (item["price"] as num)
                                      .toDouble();
                                  final qty = (item["quantity"] ?? 0) as int;
                                  final subtotal = price * qty;

                                  return pw.TableRow(
                                    children: [
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(4),
                                        child: pw.Text(
                                          "${item["code"]} - ${item["category"]}",
                                        ),
                                      ),
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(4),
                                        child: pw.Text("$qty"),
                                      ),
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(4),
                                        child: pw.Text(
                                          "₱${price.toStringAsFixed(2)}",
                                        ),
                                      ),
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(4),
                                        child: pw.Text(
                                          "₱${subtotal.toStringAsFixed(2)}",
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),

                            pw.SizedBox(height: 12),

                            // Totals
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

                // Save/share PDF
                await Printing.sharePdf(
                  bytes: await pdf.save(),
                  filename: "receipt.pdf",
                );

                if (mounted) {
                  setState(() {
                    cart.clear();
                  });
                  if (mounted && context.mounted) {
                    Navigator.pop(context);
                  }
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
