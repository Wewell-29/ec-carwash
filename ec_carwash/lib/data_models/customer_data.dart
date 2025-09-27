import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _parseDate(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString()) ?? DateTime.now();
}

/// Helper to coerce any Firestore value to String safely (handles int/double/null)
String _toString(dynamic v) => v == null ? '' : v.toString();

class Customer {
  final String? id;
  final String name;
  final String plateNumber;
  final String email; // Firestore: 'email'
  final String phoneNumber; // Firestore: 'contactNumber' (mapped below)
  final DateTime createdAt;
  final DateTime lastVisit;
  final String? vehicleType; // Firestore: 'vehicleType'

  Customer({
    this.id,
    required this.name,
    required this.plateNumber,
    required this.email,
    required this.phoneNumber,
    required this.createdAt,
    required this.lastVisit,
    this.vehicleType,
  });

  /// Full write (used for create or full update)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'plateNumber': plateNumber.toUpperCase(),
      'email': email,
      // write to Firestore using 'contactNumber' key (mirror to phoneNumber for legacy)
      'contactNumber': phoneNumber,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt.toIso8601String(),
      'lastVisit': lastVisit.toIso8601String(),
      if (vehicleType != null) 'vehicleType': vehicleType,
    };
  }

  /// Partial write for patch-style updates (e.g., only vehicleType)
  Map<String, dynamic> toPartialJson({
    bool includeEmail = false,
    bool includeContactNumber = false,
    bool includeVehicleType = false,
    bool includeTimestamps = false,
  }) {
    final map = <String, dynamic>{};
    if (includeEmail) map['email'] = email;
    if (includeContactNumber) {
      map['contactNumber'] = phoneNumber;
      map['phoneNumber'] = phoneNumber;
    }
    if (includeVehicleType) map['vehicleType'] = vehicleType;
    if (includeTimestamps) {
      map['createdAt'] = createdAt.toIso8601String();
      map['lastVisit'] = lastVisit.toIso8601String();
    }
    return map;
  }

  factory Customer.fromJson(Map<String, dynamic> json, String docId) {
    return Customer(
      id: docId,
      name: _toString(json['name']),
      plateNumber: _toString(json['plateNumber']),
      email: _toString(json['email']),
      // prefer contactNumber; fallback to legacy phoneNumber; coerce to string
      phoneNumber: _toString(json['contactNumber'] ?? json['phoneNumber']),
      createdAt: _parseDate(json['createdAt']),
      lastVisit: _parseDate(json['lastVisit']),
      vehicleType: json['vehicleType'] == null
          ? null
          : _toString(json['vehicleType']),
    );
  }

  Customer copyWith({
    String? id,
    String? name,
    String? plateNumber,
    String? email,
    String? phoneNumber,
    DateTime? createdAt,
    DateTime? lastVisit,
    String? vehicleType,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      plateNumber: plateNumber ?? this.plateNumber,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
      lastVisit: lastVisit ?? this.lastVisit,
      vehicleType: vehicleType ?? this.vehicleType,
    );
  }
}

class CustomerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'Customers';

  static Future<String> saveCustomer(Customer customer) async {
    try {
      if (customer.id != null) {
        // Use set(merge:true) for safe updates
        final ref = _firestore.collection(_collection).doc(customer.id);
        await ref.set(customer.toJson(), SetOptions(merge: true));
        return customer.id!;
      } else {
        final ref = await _firestore
            .collection(_collection)
            .add(customer.toJson());
        return ref.id;
      }
    } catch (e) {
      throw Exception('Failed to save customer: $e');
    }
  }

  /// Patch vehicleType only (doesn't touch other fields)
  static Future<void> patchVehicleType({
    required String customerId,
    required String vehicleType,
  }) async {
    try {
      await _firestore.collection(_collection).doc(customerId).set({
        'vehicleType': vehicleType,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to patch vehicleType: $e');
    }
  }

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

  static Future<List<Customer>> searchCustomersByName(String name) async {
    try {
      final q = await _firestore
          .collection(_collection)
          .orderBy('name')
          .startAt([name])
          .endAt([name + '\uf8ff'])
          .limit(10)
          .get();

      return q.docs
          .map((doc) => Customer.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to search customers by name: $e');
    }
  }

  static Future<void> updateLastVisit(String customerId) async {
    try {
      await _firestore.collection(_collection).doc(customerId).set({
        'lastVisit': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update last visit: $e');
    }
  }

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
}
