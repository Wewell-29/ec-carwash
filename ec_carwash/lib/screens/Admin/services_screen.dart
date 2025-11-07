import 'package:flutter/material.dart';
import 'package:ec_carwash/data_models/services_data.dart';

class ServicesScreen extends StatefulWidget {
  final Function(VoidCallback)? onShowAddDialog;

  const ServicesScreen({super.key, this.onShowAddDialog});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<Service> _allServices = [];
  List<String> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();

    // Register the add dialog callback with parent
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.onShowAddDialog != null) {
        widget.onShowAddDialog!(_showAddServiceDialog);
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final services = await ServicesManager.getAllServices();
      final categories = await ServicesManager.getCategories();
      setState(() {
        _allServices = services;
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading services: $e')),
        );
      }
    }
  }

  List<Service> get _filteredServices {
    List<Service> services = _allServices;

    if (_selectedCategory != 'All') {
      services = services.where((service) => service.category == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      services = services.where((service) =>
        service.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        service.code.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    // Sort services in proper order: EC1-15, UPGRADE1-4, PROMO1-4 (same as POS)
    services.sort((a, b) {
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

      final priorityA = getSortPriority(a.code);
      final priorityB = getSortPriority(b.code);

      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }

      // Within same category, sort by number
      return getCodeNumber(a.code).compareTo(getCodeNumber(b.code));
    });

    return services;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isWide = MediaQuery.of(context).size.width > 800;
    final categories = ['All', ..._categories];

    // Ensure selected category is in the list (even if all services are inactive)
    if (_selectedCategory.isNotEmpty && !categories.contains(_selectedCategory)) {
      categories.add(_selectedCategory);
    }

    return Column(
      children: [
        _buildFilters(categories, isWide),
        Expanded(
          child: _buildServicesList(isWide),
        ),
      ],
    );
  }

  Widget _buildFilters(List<String> categories, bool isWide) {
    final activeServices = _allServices.where((service) => service.isActive).length;
    final totalServices = _allServices.length;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search services...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButton<String>(
                  value: categories.contains(_selectedCategory) ? _selectedCategory : 'All',
                  underline: const SizedBox(),
                  hint: const Text('Category'),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                  },
                  items: categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade50,
                  border: Border.all(color: Colors.black87, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.black87, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '$activeServices / $totalServices Active',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServicesList(bool isWide) {
    final services = _filteredServices;

    if (services.isEmpty) {
      return const Center(
        child: Text('No services found'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        // Shorten code for display: PROMO4 -> PR4, UPGRADE1 -> UP1
        String displayCode = service.code
            .replaceAll('PROMO', 'PR')
            .replaceAll('UPGRADE', 'UP');

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.yellow.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.black87, width: 1.5),
          ),
          elevation: 2,
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black87, width: 1),
              ),
              child: CircleAvatar(
                backgroundColor: service.isActive ? Colors.yellow.shade700 : Colors.yellow.shade100,
                child: Text(
                  displayCode,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            title: Text(
              service.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 17,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Category: ${service.category}',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                if (!service.isActive)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.yellow.shade700,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black87, width: 1),
                    ),
                    child: const Text(
                      'INACTIVE',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toggle Active/Inactive button
                ElevatedButton.icon(
                  onPressed: () => _toggleServiceStatus(service),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: service.isActive ? Colors.yellow.shade700 : Colors.yellow.shade200,
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Colors.black87, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    elevation: 2,
                  ),
                  icon: Icon(
                    service.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                    size: 20,
                  ),
                  label: Text(
                    service.isActive ? 'Active' : 'Inactive',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showEditServiceDialog(service);
                        break;
                      case 'delete':
                        _showDeleteConfirmation(service);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Edit'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete),
                        title: Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.black.withValues(alpha: 0.2), width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Description:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.description,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Prices:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...service.prices.entries.map((entry) =>
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, bottom: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key,
                                style: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              '₱${entry.value.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontSize: 15,
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
      },
    );
  }

  void _showEditServiceDialog(Service service) {
    final codeController = TextEditingController(text: service.code);
    final nameController = TextEditingController(text: service.name);
    final categoryController = TextEditingController(text: service.category);
    final descriptionController = TextEditingController(text: service.description);

    // Check if this is a repaint service (special case)
    final isRepaintService = service.code.toUpperCase() == 'RPT' ||
                             service.name.toLowerCase().contains('repaint');

    // For repaint: use Standard/Premium, otherwise use vehicle types
    final List<String> priceOptions = isRepaintService
        ? ['Standard', 'Premium']
        : [
            'Cars',
            'SUV',
            'Van',
            'Pick-Up',
            'Delivery Truck (S)',
            'Delivery Truck (L)',
            'Motorcycle (S)',
            'Motorcycle (L)',
            'Tricycle',
          ];

    // Dynamic prices map
    Map<String, TextEditingController> priceControllers = {};
    Map<String, bool> selectedPriceOptions = {};

    // Initialize controllers and selected states based on existing service data
    for (String option in priceOptions) {
      priceControllers[option] = TextEditingController();
      selectedPriceOptions[option] = service.prices.containsKey(option);

      if (service.prices.containsKey(option)) {
        priceControllers[option]!.text = service.prices[option]!.toString();
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Service'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Service Code'),
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Service Name'),
                ),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  isRepaintService ? 'Price Options:' : 'Vehicle Types & Prices:',
                  style: const TextStyle(fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 8),
                ...priceOptions.map((option) => Column(
                  children: [
                    CheckboxListTile(
                      dense: true,
                      title: Text(option),
                      value: selectedPriceOptions[option],
                      onChanged: (bool? value) {
                        setDialogState(() {
                          selectedPriceOptions[option] = value ?? false;
                          // Clear price when unchecked
                          if (!(value ?? false)) {
                            priceControllers[option]!.clear();
                          }
                        });
                      },
                    ),
                    if (selectedPriceOptions[option] == true)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                        child: TextField(
                          controller: priceControllers[option],
                          decoration: InputDecoration(
                            labelText: '$option Price',
                            prefixText: '₱',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                  ],
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (codeController.text.isNotEmpty &&
                    nameController.text.isNotEmpty &&
                    categoryController.text.isNotEmpty &&
                    descriptionController.text.isNotEmpty) {

                  // Build prices map for selected options
                  Map<String, double> prices = {};
                  bool hasValidPrices = true;

                  for (String option in priceOptions) {
                    if (selectedPriceOptions[option] == true) {
                      final priceText = priceControllers[option]!.text;
                      if (priceText.isEmpty) {
                        hasValidPrices = false;
                        break;
                      }
                      final price = double.tryParse(priceText);
                      if (price == null) {
                        hasValidPrices = false;
                        break;
                      }
                      prices[option] = price;
                    }
                  }

                  if (!hasValidPrices || prices.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please enter valid prices for selected ${isRepaintService ? "options" : "vehicle types"}')),
                      );
                    }
                    return;
                  }

                  try {
                    final updatedService = service.copyWith(
                      code: codeController.text.trim().toUpperCase(),
                      name: nameController.text.trim(),
                      category: categoryController.text.trim(),
                      description: descriptionController.text.trim(),
                      prices: prices,
                      updatedAt: DateTime.now(),
                    );

                    await ServicesManager.updateService(service.id, updatedService);
                    await _loadData();
                    if (mounted) Navigator.pop(context);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Service updated successfully!')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating service: $e')),
                      );
                    }
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill in all required fields')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // Add new service dialog
  void _showAddServiceDialog() {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final descriptionController = TextEditingController();

    // All possible vehicle types
    final List<String> allVehicleTypes = [
      'Cars',
      'SUV',
      'Van',
      'Pick-Up',
      'Delivery Truck (S)',
      'Delivery Truck (L)',
      'Motorcycle (S)',
      'Motorcycle (L)',
      'Tricycle',
    ];

    // Dynamic vehicle prices map
    Map<String, TextEditingController> vehicleControllers = {};
    Map<String, bool> selectedVehicleTypes = {};

    // Initialize controllers
    for (String type in allVehicleTypes) {
      vehicleControllers[type] = TextEditingController();
      selectedVehicleTypes[type] = false;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Service'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Service Code (e.g., EC17)'),
                  textCapitalization: TextCapitalization.characters,
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Service Name'),
                ),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                const Text('Vehicle Types & Prices:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...allVehicleTypes.map((vehicleType) => Column(
                  children: [
                    CheckboxListTile(
                      dense: true,
                      title: Text(vehicleType),
                      value: selectedVehicleTypes[vehicleType],
                      onChanged: (bool? value) {
                        setDialogState(() {
                          selectedVehicleTypes[vehicleType] = value ?? false;
                          if (!(value ?? false)) {
                            vehicleControllers[vehicleType]!.clear();
                          }
                        });
                      },
                    ),
                    if (selectedVehicleTypes[vehicleType] == true)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                        child: TextField(
                          controller: vehicleControllers[vehicleType],
                          decoration: InputDecoration(
                            labelText: '$vehicleType Price',
                            prefixText: '₱',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                  ],
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (codeController.text.isNotEmpty &&
                    nameController.text.isNotEmpty &&
                    categoryController.text.isNotEmpty &&
                    descriptionController.text.isNotEmpty) {

                  // Build prices map
                  Map<String, double> prices = {};
                  bool hasValidPrices = true;

                  for (String vehicleType in allVehicleTypes) {
                    if (selectedVehicleTypes[vehicleType] == true) {
                      final priceText = vehicleControllers[vehicleType]!.text;
                      if (priceText.isEmpty) {
                        hasValidPrices = false;
                        break;
                      }
                      final price = double.tryParse(priceText);
                      if (price == null) {
                        hasValidPrices = false;
                        break;
                      }
                      prices[vehicleType] = price;
                    }
                  }

                  if (!hasValidPrices || prices.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter valid prices for at least one vehicle type')),
                      );
                    }
                    return;
                  }

                  try {
                    final newService = Service(
                      id: '', // Firestore will generate
                      code: codeController.text.trim().toUpperCase(),
                      name: nameController.text.trim(),
                      category: categoryController.text.trim(),
                      description: descriptionController.text.trim(),
                      prices: prices,
                      isActive: true,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );

                    await ServicesManager.addService(newService);
                    await _loadData();
                    if (mounted) Navigator.pop(context);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Service added successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error adding service: $e')),
                      );
                    }
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill in all required fields')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow.shade700,
                foregroundColor: Colors.black87,
              ),
              child: const Text('Add Service'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleServiceStatus(Service service) async {
    try {
      final updatedService = service.copyWith(
        isActive: !service.isActive,
        updatedAt: DateTime.now(),
      );
      await ServicesManager.updateService(service.id, updatedService);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating service status: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmation(Service service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text('Are you sure you want to delete "${service.name}"? This will deactivate the service.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ServicesManager.deleteService(service.id);
                await _loadData();
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting service: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}