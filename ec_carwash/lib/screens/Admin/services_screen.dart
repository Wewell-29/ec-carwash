import 'package:flutter/material.dart';
import 'package:ec_carwash/data_models/services_data.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

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
    final activeServices = _allServices.where((service) => service.isActive).length;
    final inactiveServices = _allServices.where((service) => !service.isActive).length;

    return Column(
      children: [
        _buildQuickActions(activeServices),
        _buildFilters(categories, isWide),
        _buildSummaryCards(activeServices, inactiveServices, isWide),
        Expanded(
          child: _buildServicesList(isWide),
        ),
      ],
    );
  }

  Widget _buildQuickActions(int activeServices) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showAddServiceDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow.shade700,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 3,
              ),
              icon: const Icon(Icons.add, weight: 600),
              label: const Text('Add New Service', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _loadData(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(List<String> categories, bool isWide) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search services...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _selectedCategory,
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(int activeServices, int inactiveServices, bool isWide) {
    final totalServices = activeServices + inactiveServices;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Total Services',
              totalServices.toString(),
              Icons.build,
              Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              'Active',
              activeServices.toString(),
              Icons.check_circle,
              Colors.green.shade700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              'Inactive',
              inactiveServices.toString(),
              Icons.cancel,
              Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: service.isActive ? Colors.green : Colors.red,
              child: Text(
                service.code,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            title: Text(
              service.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Category: ${service.category}'),
                Text('Code: ${service.code}'),
                if (!service.isActive)
                  const Text(
                    'INACTIVE',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showEditServiceDialog(service);
                        break;
                      case 'toggle':
                        _toggleServiceStatus(service);
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
                    PopupMenuItem(
                      value: 'toggle',
                      child: ListTile(
                        leading: Icon(service.isActive ? Icons.pause : Icons.play_arrow),
                        title: Text(service.isActive ? 'Deactivate' : 'Activate'),
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
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description:',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(service.description),
                    const SizedBox(height: 8),
                    Text(
                      'Prices:',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...service.prices.entries.map((entry) =>
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: Text('${entry.key}: ₱${entry.value.toStringAsFixed(2)}'),
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

    // Initialize with basic 4 types selected by default
    for (String type in allVehicleTypes) {
      vehicleControllers[type] = TextEditingController();
      selectedVehicleTypes[type] = ['Cars', 'SUV', 'Van', 'Pick-Up'].contains(type);
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
                  decoration: const InputDecoration(labelText: 'Service Code (e.g., EC16)'),
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
                )).toList(),
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

                  // Build prices map for selected vehicle types
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
                        const SnackBar(content: Text('Please enter valid prices for selected vehicle types')),
                      );
                    }
                    return;
                  }

                  try {
                    final newService = Service(
                      id: '',
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
                        const SnackBar(content: Text('Service added successfully!')),
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
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditServiceDialog(Service service) {
    final codeController = TextEditingController(text: service.code);
    final nameController = TextEditingController(text: service.name);
    final categoryController = TextEditingController(text: service.category);
    final descriptionController = TextEditingController(text: service.description);

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

    // Initialize controllers and selected states based on existing service data
    for (String type in allVehicleTypes) {
      vehicleControllers[type] = TextEditingController();
      selectedVehicleTypes[type] = service.prices.containsKey(type);

      if (service.prices.containsKey(type)) {
        vehicleControllers[type]!.text = service.prices[type]!.toString();
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
                          // Clear price when unchecked
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

                  // Build prices map for selected vehicle types
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
                        const SnackBar(content: Text('Please enter valid prices for selected vehicle types')),
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