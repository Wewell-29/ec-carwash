import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String? id;
  final String name;
  final String plateNumber;
  final String email;
  final String phoneNumber;
  final DateTime createdAt;
  final DateTime lastVisit;

  Customer({
    this.id,
    required this.name,
    required this.plateNumber,
    required this.email,
    required this.phoneNumber,
    required this.createdAt,
    required this.lastVisit,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'plateNumber': plateNumber.toUpperCase(),
      'email': email,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt.toIso8601String(),
      'lastVisit': lastVisit.toIso8601String(),
    };
  }

  factory Customer.fromJson(Map<String, dynamic> json, String docId) {
    return Customer(
      id: docId,
      name: json['name'] ?? '',
      plateNumber: json['plateNumber'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      lastVisit: DateTime.parse(json['lastVisit'] ?? DateTime.now().toIso8601String()),
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
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      plateNumber: plateNumber ?? this.plateNumber,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
      lastVisit: lastVisit ?? this.lastVisit,
    );
  }
}

class CustomerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'customers';

  static Future<String> saveCustomer(Customer customer) async {
    try {
      DocumentReference docRef;

      if (customer.id != null) {
        // Update existing customer
        docRef = _firestore.collection(_collection).doc(customer.id);
        await docRef.update(customer.toJson());
        return customer.id!;
      } else {
        // Create new customer
        docRef = await _firestore.collection(_collection).add(customer.toJson());
        return docRef.id;
      }
    } catch (e) {
      throw Exception('Failed to save customer: $e');
    }
  }

  static Future<Customer?> getCustomerByPlateNumber(String plateNumber) async {
    try {
      final QuerySnapshot query = await _firestore
          .collection(_collection)
          .where('plateNumber', isEqualTo: plateNumber.toUpperCase())
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return Customer.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get customer by plate number: $e');
    }
  }

  static Future<List<Customer>> searchCustomersByName(String name) async {
    try {
      final QuerySnapshot query = await _firestore
          .collection(_collection)
          .where('name', isGreaterThanOrEqualTo: name)
          .where('name', isLessThanOrEqualTo: name + '\uf8ff')
          .orderBy('name')
          .limit(10)
          .get();

      return query.docs.map((doc) {
        return Customer.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to search customers by name: $e');
    }
  }

  static Future<void> updateLastVisit(String customerId) async {
    try {
      await _firestore.collection(_collection).doc(customerId).update({
        'lastVisit': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update last visit: $e');
    }
  }

  static Future<List<Customer>> getRecentCustomers({int limit = 10}) async {
    try {
      final QuerySnapshot query = await _firestore
          .collection(_collection)
          .orderBy('lastVisit', descending: true)
          .limit(limit)
          .get();

      return query.docs.map((doc) {
        return Customer.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get recent customers: $e');
    }
  }
}