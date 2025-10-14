import 'package:cloud_firestore/cloud_firestore.dart';

/// Unified Transaction model for all payment transactions
/// Used by: POS, Scheduling (when marking booking as complete)
class Transaction {
  final String? id;
  final String customerName;
  final String? customerId; // FK to Customers collection
  final String vehiclePlateNumber;
  final String? contactNumber;
  final String? vehicleType;

  // Services provided in this transaction
  final List<TransactionService> services;
  final double subtotal;
  final double discount;
  final double total;

  // Payment details
  final double cash;
  final double change;
  final String paymentMethod; // 'cash', 'gcash', 'card', etc.
  final String paymentStatus; // 'paid', 'pending', 'refunded'

  // Team assignment
  final String? assignedTeam;
  final double teamCommission;

  // Timestamps
  final DateTime transactionDate; // Date only (for daily reports)
  final DateTime transactionAt; // Full timestamp (exact time)
  final DateTime createdAt;

  // Source tracking and relationships
  final String source; // 'pos', 'booking', 'walk-in'
  final String? bookingId; // FK to Bookings collection (if from booking)

  // Additional metadata
  final String status; // 'completed', 'cancelled', 'refunded'
  final String? notes;

  Transaction({
    this.id,
    required this.customerName,
    this.customerId,
    required this.vehiclePlateNumber,
    this.contactNumber,
    this.vehicleType,
    required this.services,
    required this.subtotal,
    this.discount = 0.0,
    required this.total,
    required this.cash,
    required this.change,
    this.paymentMethod = 'cash',
    this.paymentStatus = 'paid',
    this.assignedTeam,
    this.teamCommission = 0.0,
    required this.transactionDate,
    required this.transactionAt,
    required this.createdAt,
    required this.source,
    this.bookingId,
    this.status = 'completed',
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'customerName': customerName,
      'customerId': customerId,
      'vehiclePlateNumber': vehiclePlateNumber.toUpperCase(),
      'contactNumber': contactNumber,
      'vehicleType': vehicleType,
      'services': services.map((s) => s.toJson()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'total': total,
      'cash': cash,
      'change': change,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'assignedTeam': assignedTeam,
      'teamCommission': teamCommission,
      'transactionDate': Timestamp.fromDate(transactionDate),
      'transactionAt': Timestamp.fromDate(transactionAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'source': source,
      'bookingId': bookingId,
      'status': status,
      'notes': notes,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json, String docId) {
    return Transaction(
      id: docId,
      customerName: json['customerName'] ?? '',
      customerId: json['customerId'],
      vehiclePlateNumber: json['vehiclePlateNumber'] ?? '',
      contactNumber: json['contactNumber'],
      vehicleType: json['vehicleType'],
      services: (json['services'] as List<dynamic>? ?? [])
          .map((s) => TransactionService.fromJson(s as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] ?? json['total'] ?? 0).toDouble(),
      discount: (json['discount'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      cash: (json['cash'] ?? 0).toDouble(),
      change: (json['change'] ?? 0).toDouble(),
      paymentMethod: json['paymentMethod'] ?? 'cash',
      paymentStatus: json['paymentStatus'] ?? 'paid',
      assignedTeam: json['assignedTeam'],
      teamCommission: (json['teamCommission'] ?? 0).toDouble(),
      transactionDate: (json['transactionDate'] as Timestamp?)?.toDate() ??
          (json['date'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      transactionAt: (json['transactionAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      source: json['source'] ?? 'pos',
      bookingId: json['bookingId'],
      status: json['status'] ?? 'completed',
      notes: json['notes'],
    );
  }

  Transaction copyWith({
    String? id,
    String? customerName,
    String? customerId,
    String? vehiclePlateNumber,
    String? contactNumber,
    String? vehicleType,
    List<TransactionService>? services,
    double? subtotal,
    double? discount,
    double? total,
    double? cash,
    double? change,
    String? paymentMethod,
    String? paymentStatus,
    String? assignedTeam,
    double? teamCommission,
    DateTime? transactionDate,
    DateTime? transactionAt,
    DateTime? createdAt,
    String? source,
    String? bookingId,
    String? status,
    String? notes,
  }) {
    return Transaction(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerId: customerId ?? this.customerId,
      vehiclePlateNumber: vehiclePlateNumber ?? this.vehiclePlateNumber,
      contactNumber: contactNumber ?? this.contactNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      services: services ?? this.services,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      cash: cash ?? this.cash,
      change: change ?? this.change,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      assignedTeam: assignedTeam ?? this.assignedTeam,
      teamCommission: teamCommission ?? this.teamCommission,
      transactionDate: transactionDate ?? this.transactionDate,
      transactionAt: transactionAt ?? this.transactionAt,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
      bookingId: bookingId ?? this.bookingId,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}

/// Service item within a transaction (unified with BookingService)
class TransactionService {
  final String serviceCode;
  final String serviceName;
  final String vehicleType;
  final double price;
  final int quantity;

  TransactionService({
    required this.serviceCode,
    required this.serviceName,
    required this.vehicleType,
    required this.price,
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'serviceCode': serviceCode,
      'serviceName': serviceName,
      'vehicleType': vehicleType,
      'price': price,
      'quantity': quantity,
    };
  }

  factory TransactionService.fromJson(Map<String, dynamic> json) {
    return TransactionService(
      serviceCode: json['serviceCode'] ?? '',
      serviceName: json['serviceName'] ?? '',
      vehicleType: json['vehicleType'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 1,
    );
  }
}

class TransactionManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'Transactions';

  /// Create a transaction from POS
  static Future<String> createTransaction(Transaction transaction) async {
    try {
      final docRef = await _firestore
          .collection(_collection)
          .add(transaction.toJson());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create transaction: $e');
    }
  }

  /// Create transaction from a completed booking
  static Future<String> createFromBooking({
    required String bookingId,
    required String customerName,
    required String? customerId,
    required String vehiclePlateNumber,
    required String? contactNumber,
    required String? vehicleType,
    required List<TransactionService> services,
    required double total,
    required DateTime scheduledDateTime,
    String? assignedTeam,
    double teamCommission = 0.0,
  }) async {
    final now = DateTime.now();
    final transaction = Transaction(
      customerName: customerName,
      customerId: customerId,
      vehiclePlateNumber: vehiclePlateNumber,
      contactNumber: contactNumber,
      vehicleType: vehicleType,
      services: services,
      subtotal: total,
      discount: 0.0,
      total: total,
      cash: total, // Assume exact payment for bookings
      change: 0.0,
      paymentMethod: 'cash',
      paymentStatus: 'paid',
      assignedTeam: assignedTeam,
      teamCommission: teamCommission,
      transactionDate: DateTime(now.year, now.month, now.day),
      transactionAt: scheduledDateTime,
      createdAt: now,
      source: 'booking',
      bookingId: bookingId,
      status: 'completed',
    );

    return await createTransaction(transaction);
  }

  /// Get all transactions
  static Future<List<Transaction>> getTransactions() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('transactionAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Transaction.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get transactions: $e');
    }
  }

  /// Get transactions by date range
  static Future<List<Transaction>> getTransactionsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('transactionDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('transactionDate',
              isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('transactionDate', descending: true)
          .orderBy('transactionAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Transaction.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get transactions by date range: $e');
    }
  }

  /// Get today's transactions
  static Future<List<Transaction>> getTodayTransactions() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    return await getTransactionsByDateRange(
      startDate: startOfDay,
      endDate: endOfDay,
    );
  }

  /// Get transactions by customer
  static Future<List<Transaction>> getTransactionsByCustomer(
      String customerId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('customerId', isEqualTo: customerId)
          .orderBy('transactionAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Transaction.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get transactions by customer: $e');
    }
  }

  /// Get transaction by booking ID
  static Future<Transaction?> getTransactionByBookingId(
      String bookingId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('bookingId', isEqualTo: bookingId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return Transaction.fromJson(snapshot.docs.first.data(),
            snapshot.docs.first.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get transaction by booking ID: $e');
    }
  }

  /// Update transaction status
  static Future<void> updateTransactionStatus(
      String transactionId, String status) async {
    try {
      await _firestore.collection(_collection).doc(transactionId).update({
        'status': status,
      });
    } catch (e) {
      throw Exception('Failed to update transaction status: $e');
    }
  }

  /// Calculate total revenue for date range
  static Future<double> calculateRevenue({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final transactions = await getTransactionsByDateRange(
      startDate: startDate,
      endDate: endDate,
    );

    return transactions
        .where((t) => t.status == 'completed' && t.paymentStatus == 'paid')
        .fold<double>(0.0, (total, t) => total + t.total);
  }
}
