import 'package:cloud_firestore/cloud_firestore.dart';

class Service {
  final String id;
  final String code;
  final String name;
  final String category;
  final String description;
  final Map<String, double> prices; // e.g., {'Sedan': 150.0, 'SUV': 200.0}
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Service({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.description,
    required this.prices,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  Service copyWith({
    String? id,
    String? code,
    String? name,
    String? category,
    String? description,
    Map<String, double>? prices,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Service(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      prices: prices ?? this.prices,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'name': name,
      'category': category,
      'description': description,
      'prices': prices,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Service.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Coerce prices to Map<String, double> regardless of incoming numeric type
    final Map<String, double> parsedPrices = {};
    final rawPrices = data['prices'];
    if (rawPrices is Map) {
      rawPrices.forEach((key, value) {
        if (key is String) {
          if (value is num) {
            parsedPrices[key] = value.toDouble();
          } else if (value is String) {
            final d = double.tryParse(value);
            if (d != null) parsedPrices[key] = d; // skip invalids silently
          }
        }
      });
    }

    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is int) {
        // Heuristic: treat >= 10^12 as millis, else seconds
        final isMillis = v.abs() >= 1000000000000;
        return DateTime.fromMillisecondsSinceEpoch(isMillis ? v : v * 1000);
      }
      if (v is String) {
        final dt = DateTime.tryParse(v);
        if (dt != null) return dt;
      }
      return DateTime.now();
    }

    return Service(
      id: doc.id,
      code: (data['code'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      prices: parsedPrices,
      isActive: (data['isActive'] is bool) ? data['isActive'] as bool : true,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }
}

List<Service> initialServices = [
  // Basic Services EC1-EC15
  Service(
    id: '',
    code: 'EC1',
    name: 'Carwash Vacuum Tire Black',
    category: 'Basic Wash',
    description: 'Basic carwash with vacuum and tire black treatment',
    prices: {
      'Cars': 170.0,
      'SUV': 180.0,
      'Van': 200.0,
      'Pick-Up': 200.0,
      'Delivery Truck (S)': 500.0,
      'Delivery Truck (L)': 800.0,
      'Motorcycle (S)': 150.0,
      'Motorcycle (L)': 180.0,
      'Tricycle': 200.0,
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Service(
    id: '',
    code: 'EC2',
    name: 'Carwash Vacuum Tire Black Armor All Spray Wax',
    category: 'Premium Wash',
    description: 'Premium wash with vacuum, tire black, and Armor All spray wax',
    prices: {
      'Cars': 250.0,
      'SUV': 280.0,
      'Van': 350.0,
      'Pick-Up': 350.0,
      'Delivery Truck (S)': 550.0,
      'Delivery Truck (L)': 850.0,
      'Motorcycle (S)': 170.0,
      'Motorcycle (L)': 200.0,
      'Tricycle': 220.0,
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Service(
    id: '',
    code: 'EC3',
    name: 'Carwash Vacuum Tire Black Armor All Hand Wax',
    category: 'Premium Wash',
    description: 'Premium wash with vacuum, tire black, and Armor All hand wax',
    prices: {
      'Cars': 300.0,
      'SUV': 400.0,
      'Van': 450.0,
      'Pick-Up': 450.0,
      'Delivery Truck (S)': 600.0,
      'Delivery Truck (L)': 900.0,
      'Motorcycle (S)': 200.0,
      'Motorcycle (L)': 220.0,
      'Tricycle': 250.0,
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Service(
    id: '',
    code: 'EC4',
    name: 'Carwash Vacuum Tire Black Armor All Wax Polishing',
    category: 'Premium Wash',
    description: 'Complete wash with vacuum, tire black, Armor All wax and polishing',
    prices: {
      'Cars': 500.0,
      'SUV': 550.0,
      'Van': 600.0,
      'Pick-Up': 600.0,
      'Delivery Truck (S)': 650.0,
      'Delivery Truck (L)': 950.0,
      'Motorcycle (S)': 230.0,
      'Motorcycle (L)': 250.0,
      'Tricycle': 280.0,
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Service(
    id: '',
    code: 'EC5',
    name: 'Full Buffing',
    category: 'Detailing',
    description: 'Complete car buffing service for paint restoration',
    prices: {
      'Cars': 1500.0,
      'SUV': 2000.0,
      'Van': 2500.0,
      'Pick-Up': 2500.0,
      'Delivery Truck (S)': 2500.0,
      'Delivery Truck (L)': 2500.0,
      // No motorcycles/tricycles for EC5
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Service(
    id: '',
    code: 'EC6',
    name: 'Car Sanitation Original Back to Zero',
    category: 'Sanitization',
    description: 'Complete car sanitization using Original Back to Zero products',
    prices: {
      'Cars': 450.0,
      'SUV': 500.0,
      'Van': 500.0,
      'Pick-Up': 550.0,
      'Delivery Truck (S)': 450.0,
      'Delivery Truck (L)': 450.0,
      // No motorcycles/tricycles for EC6
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Service(
    id: '',
    code: 'EC7',
    name: 'Engine Wash',
    category: 'Engine',
    description: 'Thorough engine bay cleaning and degreasing',
    prices: {
      'Cars': 350.0,
      'SUV': 400.0,
      'Van': 450.0,
      'Pick-Up': 450.0,
      'Delivery Truck (S)': 500.0,
      'Delivery Truck (L)': 550.0,
      // No motorcycles/tricycles for EC7
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Service(
    id: '',
    code: 'EC8',
    name: 'Under Wash',
    category: 'Undercarriage',
    description: 'Complete undercarriage cleaning and washing',
    prices: {
      'Cars': 500.0,
      'SUV': 550.0,
      'Van': 600.0,
      'Pick-Up': 600.0,
      'Delivery Truck (S)': 700.0,
      'Delivery Truck (L)': 700.0,
      // No motorcycles/tricycles for EC8
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Service(
    id: '',
    code: 'EC9',
    name: 'Glass Acid Removal',
    category: 'Glass Treatment',
    description: 'Professional glass acid removal treatment',
    prices: {
      'Cars': 800.0,
      'SUV': 1000.0,
      'Van': 1200.0,
      'Pick-Up': 1200.0,
      'Delivery Truck (S)': 1000.0,
      'Delivery Truck (L)': 1000.0,
      // No motorcycles/tricycles for EC9
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Service(
    id: '',
    code: 'EC10',
    name: 'Body Acid Removal',
    category: 'Paint Treatment',
    description: 'Professional body acid removal treatment',
    prices: {
      'Cars': 1000.0,
      'SUV': 1500.0,
      'Van': 1500.0,
      'Pick-Up': 1500.0,
      'Delivery Truck (S)': 1200.0,
      'Delivery Truck (L)': 1200.0,
      // No motorcycles/tricycles for EC10
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Service(
    id: '',
    code: 'EC11',
    name: 'Interior Detailing',
    category: 'Detailing',
    description: 'Complete interior detailing service',
    prices: {
      'Cars': 4000.0,
      'SUV': 4500.0,
      'Van': 5000.0,
      'Pick-Up': 5000.0,
      'Delivery Truck (S)': 4000.0,
      'Delivery Truck (L)': 4000.0,
      'Motorcycle (S)': 2500.0,
      'Motorcycle (L)': 2500.0,
      'Tricycle': 2500.0,
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Service(
    id: '',
    code: 'EC12',
    name: 'Exterior Detailing',
    category: 'Detailing',
    description: 'Complete exterior detailing service',
    prices: {
      'Cars': 5000.0,
      'SUV': 5500.0,
      'Van': 6500.0,
      'Pick-Up': 6500.0,
      'Delivery Truck (S)': 6500.0,
      'Delivery Truck (L)': 6500.0,
      'Motorcycle (S)': 2500.0,
      'Motorcycle (L)': 2500.0,
      'Tricycle': 2500.0,
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Service(
    id: '',
    code: 'EC13',
    name: 'Seat Cover Dismantling/Installation',
    category: 'Interior',
    description: 'Professional seat cover removal and installation service',
    prices: {
      'Cars': 500.0,
      'SUV': 500.0,
      'Van': 500.0,
      'Pick-Up': 500.0,
      'Delivery Truck (S)': 500.0,
      'Delivery Truck (L)': 500.0,
      'Motorcycle (S)': 500.0,
      'Motorcycle (L)': 500.0,
      'Tricycle': 500.0,
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Service(
    id: '',
    code: 'EC14',
    name: 'Headlight Restoration',
    category: 'Restoration',
    description: 'Professional headlight restoration service',
    prices: {
      'Cars': 1000.0,
      'SUV': 1000.0,
      'Van': 1000.0,
      'Pick-Up': 1000.0,
      'Delivery Truck (S)': 1000.0,
      'Delivery Truck (L)': 1000.0,
      // No motorcycles/tricycles for EC14
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Service(
    id: '',
    code: 'EC15',
    name: 'Under Coating',
    category: 'Protection',
    description: 'Professional undercarriage protection coating',
    prices: {
      'Cars': 6000.0,
      'SUV': 7500.0,
      'Van': 9000.0,
      'Pick-Up': 8500.0,
      // No delivery trucks or motorcycles for EC15
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Service(
    id: '',
    code: 'RPT',
    name: 'Repaint Service',
    category: 'Paint',
    description: 'Professional vehicle repainting service - price per panel',
    prices: {
      'Standard': 4000.0,
      'Premium': 7500.0,
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  // Promo Packages
  Service(
    id: '',
    code: 'PROMO1',
    name: 'Carwash Wax Buffing Engine Wash',
    category: 'Promo Package',
    description: 'Promotional package: Carwash + Wax + Buffing + Engine Wash',
    prices: {
      'Cars': 650.0,
      'SUV': 750.0,
      'Van': 850.0,
      'Pick-Up': 850.0,
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Service(
    id: '',
    code: 'PROMO2',
    name: 'Carwash Under Wash Engine Wash',
    category: 'Promo Package',
    description: 'Promotional package: Carwash + Under Wash + Engine Wash',
    prices: {
      'Cars': 700.0,
      'SUV': 800.0,
      'Van': 900.0,
      'Pick-Up': 900.0,
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Service(
    id: '',
    code: 'PROMO3',
    name: 'Carwash Glass Cleaning Engine Wash',
    category: 'Promo Package',
    description: 'Promotional package: Carwash + Glass Cleaning + Engine Wash',
    prices: {
      'Cars': 1000.0,
      'SUV': 1200.0,
      'Van': 1400.0,
      'Pick-Up': 1400.0,
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Service(
    id: '',
    code: 'PROMO4',
    name: 'Carwash Under Wash Glass Cleaning',
    category: 'Promo Package',
    description: 'Promotional package: Carwash + Under Wash + Glass Cleaning',
    prices: {
      'Cars': 1200.0,
      'SUV': 1400.0,
      'Van': 1600.0,
      'Pick-Up': 1600.0,
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  // Upgrade Packages
  Service(
    id: '',
    code: 'UPGRADE1',
    name: 'Carwash Armor All Under Wash Wax Buffing Engine Wash',
    category: 'Upgrade Package',
    description: 'Upgrade package: Complete service with all premium treatments',
    prices: {
      'Cars': 1500.0,
      'SUV': 1200.0,
      'Van': 1250.0,
      'Pick-Up': 1350.0,
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Service(
    id: '',
    code: 'UPGRADE2',
    name: 'Carwash Armor All Glass Acid Removal Wax Buffing Engine Wash',
    category: 'Upgrade Package',
    description: 'Upgrade package: Premium service with glass acid removal',
    prices: {
      'Cars': 1250.0,
      'SUV': 1300.0,
      'Van': 1350.0,
      'Pick-Up': 1450.0,
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Service(
    id: '',
    code: 'UPGRADE3',
    name: 'Carwash Armor All Body Acid Removal Wax Buffing Under Wash',
    category: 'Upgrade Package',
    description: 'Upgrade package: Premium service with body acid removal',
    prices: {
      'Cars': 1450.0,
      'SUV': 1500.0,
      'Van': 1550.0,
      'Pick-Up': 1650.0,
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Service(
    id: '',
    code: 'UPGRADE4',
    name: 'Carwash Armor All Glass & Body Acid Removal Wax Buffing Under & Engine Wash',
    category: 'Upgrade Package',
    description: 'Ultimate upgrade package: Complete premium service with all treatments',
    prices: {
      'Cars': 1750.0,
      'SUV': 1850.0,
      'Van': 1950.0,
      'Pick-Up': 2000.0,
    },
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
];

class ServicesManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'services';

  static Stream<List<Service>> getServicesStream() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Service.fromFirestore(doc))
            .toList());
  }

  static Future<List<Service>> getServices() async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .get();
    final services = snapshot.docs
        .map((doc) => Service.fromFirestore(doc))
        .toList();

    // Sort in memory to avoid Firestore index requirements
    services.sort((a, b) {
      final categoryComparison = a.category.compareTo(b.category);
      if (categoryComparison != 0) return categoryComparison;
      return a.name.compareTo(b.name);
    });

    return services;
  }

  static Future<List<Service>> getAllServices() async {
    final snapshot = await _firestore
        .collection(_collection)
        .get();
    final services = snapshot.docs
        .map((doc) => Service.fromFirestore(doc))
        .toList();

    // Sort in memory to avoid Firestore index requirements
    services.sort((a, b) {
      final categoryComparison = a.category.compareTo(b.category);
      if (categoryComparison != 0) return categoryComparison;
      return a.name.compareTo(b.name);
    });

    return services;
  }

  static Future<void> addService(Service service) async {
    await _firestore.collection(_collection).add(service.toFirestore());
  }

  static Future<void> updateService(String serviceId, Service service) async {
    await _firestore.collection(_collection).doc(serviceId).update(service.toFirestore());
  }

  static Future<void> deleteService(String serviceId) async {
    await _firestore.collection(_collection).doc(serviceId).update({
      'isActive': false,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  static Future<Service?> getService(String serviceId) async {
    final doc = await _firestore.collection(_collection).doc(serviceId).get();
    if (doc.exists) {
      return Service.fromFirestore(doc);
    }
    return null;
  }

  static Future<Service?> getServiceByCode(String code) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('code', isEqualTo: code)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return Service.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  static Future<List<String>> getCategories() async {
    final services = await getAllServices();
    return services.map((service) => service.category).toSet().toList();
  }

  static Future<void> initializeWithSampleData() async {
    final snapshot = await _firestore.collection(_collection).get();
    if (snapshot.docs.isEmpty) {
      for (final service in initialServices) {
        await addService(service);
      }
    }
  }

  // Clear all services and reinitialize with updated data
  static Future<void> resetAndInitializeServices() async {
    final snapshot = await _firestore.collection(_collection).get();
    // Delete all existing services
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }

    // Add all new services
    for (final service in initialServices) {
      await addService(service);
    }
  }
}
