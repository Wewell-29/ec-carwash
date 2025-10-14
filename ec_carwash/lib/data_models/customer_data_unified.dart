import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _parseDate(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString()) ?? DateTime.now();
}

String _toString(dynamic v) => v == null ? '' : v.toString();

/// Unified Customer model with proper relational support
class Customer {
  final String? id;
  final String name;
  final String plateNumber; // Primary identifier for walk-ins
  final String email;
  final String contactNumber; // Standardized field name
  final String? vehicleType;

  // Relationship tracking
  final List<String> bookingIds; // List of booking IDs for this customer
  final List<String> transactionIds; // List of transaction IDs

  // Business metrics
  final int totalVisits;
  final double totalSpent;

  // Timestamps
  final DateTime createdAt;
  final DateTime lastVisit;

  // Customer source
  final String source; // 'customer-app', 'pos', 'walk-in'

  // Additional metadata
  final String? notes;

  Customer({
    this.id,
    required this.name,
    required this.plateNumber,
    required this.email,
    required this.contactNumber,
    this.vehicleType,
    this.bookingIds = const [],
    this.transactionIds = const [],
    this.totalVisits = 0,
    this.totalSpent = 0.0,
    required this.createdAt,
    required this.lastVisit,
    this.source = 'customer-app',
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'plateNumber': plateNumber.toUpperCase(),
      'email': email,
      'contactNumber': contactNumber,
      'vehicleType': vehicleType,
      'bookingIds': bookingIds,
      'transactionIds': transactionIds,
      'totalVisits': totalVisits,
      'totalSpent': totalSpent,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastVisit': Timestamp.fromDate(lastVisit),
      'source': source,
      'notes': notes,
    };
  }

  factory Customer.fromJson(Map<String, dynamic> json, String docId) {
    return Customer(
      id: docId,
      name: _toString(json['name']),
      plateNumber: _toString(json['plateNumber']),
      email: _toString(json['email']),
      // Unified field name - handle legacy
      contactNumber: _toString(json['contactNumber'] ?? json['phoneNumber']),
      vehicleType: json['vehicleType'] == null ? null : _toString(json['vehicleType']),
      bookingIds: (json['bookingIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      transactionIds: (json['transactionIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      totalVisits: json['totalVisits'] ?? 0,
      totalSpent: (json['totalSpent'] ?? 0).toDouble(),
      createdAt: _parseDate(json['createdAt']),
      lastVisit: _parseDate(json['lastVisit']),
      source: json['source'] ?? 'customer-app',
      notes: json['notes'],
    );
  }

  Customer copyWith({
    String? id,
    String? name,
    String? plateNumber,
    String? email,
    String? contactNumber,
    String? vehicleType,
    List<String>? bookingIds,
    List<String>? transactionIds,
    int? totalVisits,
    double? totalSpent,
    DateTime? createdAt,
    DateTime? lastVisit,
    String? source,
    String? notes,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      plateNumber: plateNumber ?? this.plateNumber,
      email: email ?? this.email,
      contactNumber: contactNumber ?? this.contactNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      bookingIds: bookingIds ?? this.bookingIds,
      transactionIds: transactionIds ?? this.transactionIds,
      totalVisits: totalVisits ?? this.totalVisits,
      totalSpent: totalSpent ?? this.totalSpent,
      createdAt: createdAt ?? this.createdAt,
      lastVisit: lastVisit ?? this.lastVisit,
      source: source ?? this.source,
      notes: notes ?? this.notes,
    );
  }
}

class CustomerManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'Customers';

  /// Create or update customer
  static Future<String> saveCustomer(Customer customer) async {
    try {
      if (customer.id != null && customer.id!.isNotEmpty) {
        // Update existing customer
        await _firestore
            .collection(_collection)
            .doc(customer.id)
            .set(customer.toJson(), SetOptions(merge: true));
        return customer.id!;
      } else {
        // Create new customer
        final docRef = await _firestore
            .collection(_collection)
            .add(customer.toJson());
        return docRef.id;
      }
    } catch (e) {
      throw Exception('Failed to save customer: $e');
    }
  }

  /// Get customer by ID
  static Future<Customer?> getCustomerById(String customerId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(customerId).get();
      if (doc.exists) {
        return Customer.fromJson(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get customer by ID: $e');
    }
  }

  /// Get customer by plate number
  static Future<Customer?> getCustomerByPlateNumber(String plateNumber) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('plateNumber', isEqualTo: plateNumber.toUpperCase())
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return Customer.fromJson(doc.data(), doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get customer by plate number: $e');
    }
  }

  /// Get customer by email
  static Future<Customer?> getCustomerByEmail(String email) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return Customer.fromJson(doc.data(), doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get customer by email: $e');
    }
  }

  /// Search customers by name
  static Future<List<Customer>> searchCustomersByName(String name) async {
    try {
      final q = await _firestore
          .collection(_collection)
          .orderBy('name')
          .startAt([name])
          .endAt(['$name\uf8ff'])
          .limit(10)
          .get();

      return q.docs
          .map((doc) => Customer.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to search customers by name: $e');
    }
  }

  /// Get recent customers
  static Future<List<Customer>> getRecentCustomers({int limit = 10}) async {
    try {
      final q = await _firestore
          .collection(_collection)
          .orderBy('lastVisit', descending: true)
          .limit(limit)
          .get();

      return q.docs
          .map((doc) => Customer.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get recent customers: $e');
    }
  }

  /// Create or update customer (find by plate number first)
  static Future<String> createOrUpdateCustomer({
    required String name,
    required String plateNumber,
    required String email,
    required String contactNumber,
    String? vehicleType,
    String source = 'customer-app',
  }) async {
    try {
      // Try to find existing customer by plate number
      final existing = await getCustomerByPlateNumber(plateNumber);

      if (existing != null) {
        // Update existing customer
        final updated = existing.copyWith(
          name: name,
          email: email,
          contactNumber: contactNumber,
          vehicleType: vehicleType ?? existing.vehicleType,
          lastVisit: DateTime.now(),
        );
        await saveCustomer(updated);
        return existing.id!;
      } else {
        // Create new customer
        final newCustomer = Customer(
          name: name,
          plateNumber: plateNumber,
          email: email,
          contactNumber: contactNumber,
          vehicleType: vehicleType,
          createdAt: DateTime.now(),
          lastVisit: DateTime.now(),
          source: source,
        );
        return await saveCustomer(newCustomer);
      }
    } catch (e) {
      throw Exception('Failed to create or update customer: $e');
    }
  }

  /// Add booking reference to customer
  static Future<void> addBookingToCustomer(String customerId, String bookingId) async {
    try {
      await _firestore.collection(_collection).doc(customerId).update({
        'bookingIds': FieldValue.arrayUnion([bookingId]),
        'lastVisit': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add booking to customer: $e');
    }
  }

  /// Add transaction reference to customer and update metrics
  static Future<void> addTransactionToCustomer({
    required String customerId,
    required String transactionId,
    required double amount,
  }) async {
    try {
      await _firestore.collection(_collection).doc(customerId).update({
        'transactionIds': FieldValue.arrayUnion([transactionId]),
        'totalVisits': FieldValue.increment(1),
        'totalSpent': FieldValue.increment(amount),
        'lastVisit': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add transaction to customer: $e');
    }
  }

  /// Update customer vehicle type
  static Future<void> updateVehicleType({
    required String customerId,
    required String vehicleType,
  }) async {
    try {
      await _firestore.collection(_collection).doc(customerId).update({
        'vehicleType': vehicleType,
      });
    } catch (e) {
      throw Exception('Failed to update vehicle type: $e');
    }
  }

  /// Update last visit timestamp
  static Future<void> updateLastVisit(String customerId) async {
    try {
      await _firestore.collection(_collection).doc(customerId).update({
        'lastVisit': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update last visit: $e');
    }
  }

  /// Get all customers
  static Future<List<Customer>> getAllCustomers() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('lastVisit', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Customer.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get all customers: $e');
    }
  }

  /// Get top customers by spending
  static Future<List<Customer>> getTopCustomers({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('totalSpent', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => Customer.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get top customers: $e');
    }
  }
}
