import 'package:cloud_firestore/cloud_firestore.dart';

/// Unified Booking Service structure (same as TransactionService)
class BookingService {
  final String serviceCode;
  final String serviceName;
  final String vehicleType;
  final double price;
  final int quantity;

  BookingService({
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

  factory BookingService.fromJson(Map<String, dynamic> json) {
    return BookingService(
      serviceCode: json['serviceCode'] ?? '',
      serviceName: json['serviceName'] ?? '',
      vehicleType: json['vehicleType'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 1,
    );
  }
}

/// Unified Booking model with proper relationships
class Booking {
  final String? id;

  // Customer information with FK
  final String userId;
  final String userEmail;
  final String userName;
  final String? customerId; // FK to Customers collection

  // Vehicle information
  final String plateNumber;
  final String contactNumber;
  final String? vehicleType;

  // Scheduling - SINGLE SOURCE OF TRUTH
  final DateTime scheduledDateTime; // The ONLY datetime field to use

  // Services
  final List<BookingService> services;

  // Status tracking
  final String status; // 'pending', 'approved', 'in-progress', 'completed', 'cancelled'
  final String paymentStatus; // 'unpaid', 'paid', 'refunded'

  // Source and relationships
  final String source; // 'customer-app', 'pos', 'walk-in', 'admin'
  final String? transactionId; // FK to Transactions (when payment is made)

  // Team assignment
  final String? assignedTeam; // 'Team A', 'Team B', or null
  final double teamCommission;

  // Timestamps
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  // Additional metadata
  final String? notes;

  Booking({
    this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    this.customerId,
    required this.plateNumber,
    required this.contactNumber,
    this.vehicleType,
    required this.scheduledDateTime,
    required this.services,
    required this.createdAt,
    this.status = 'pending',
    this.paymentStatus = 'unpaid',
    this.source = 'customer-app',
    this.transactionId,
    this.assignedTeam,
    this.teamCommission = 0.0,
    this.updatedAt,
    this.completedAt,
    this.notes,
  });

  double get totalAmount {
    return services.fold<double>(0.0, (total, service) => total + (service.price * service.quantity));
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'customerId': customerId,
      'plateNumber': plateNumber.toUpperCase(),
      'contactNumber': contactNumber,
      'vehicleType': vehicleType,
      'scheduledDateTime': Timestamp.fromDate(scheduledDateTime),
      'services': services.map((s) => s.toJson()).toList(),
      'status': status,
      'paymentStatus': paymentStatus,
      'source': source,
      'transactionId': transactionId,
      'assignedTeam': assignedTeam,
      'teamCommission': teamCommission,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'notes': notes,
    };
  }

  factory Booking.fromJson(Map<String, dynamic> json, String docId) {
    // Handle legacy datetime fields - prioritize scheduledDateTime
    DateTime scheduledDateTime;

    if (json['scheduledDateTime'] != null) {
      scheduledDateTime = (json['scheduledDateTime'] as Timestamp).toDate();
    } else if (json['selectedDateTime'] != null) {
      // Legacy field support
      scheduledDateTime = (json['selectedDateTime'] as Timestamp).toDate();
    } else if (json['date'] != null) {
      // Fallback: reconstruct from separate date field
      try {
        final dateStr = json['date'] as String;
        // This is a best-effort parse, may need adjustment
        scheduledDateTime = DateTime.parse(dateStr);
      } catch (e) {
        scheduledDateTime = DateTime.now();
      }
    } else {
      scheduledDateTime = DateTime.now();
    }

    return Booking(
      id: docId,
      userId: json['userId'] ?? '',
      userEmail: json['userEmail'] ?? '',
      userName: json['userName'] ?? '',
      customerId: json['customerId'],
      plateNumber: json['plateNumber'] ?? '',
      contactNumber: json['contactNumber'] ?? '',
      vehicleType: json['vehicleType'],
      scheduledDateTime: scheduledDateTime,
      services: (json['services'] as List<dynamic>? ?? [])
          .map((s) => BookingService.fromJson(s as Map<String, dynamic>))
          .toList(),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: json['status'] ?? 'pending',
      paymentStatus: json['paymentStatus'] ?? 'unpaid',
      source: json['source'] ?? 'customer-app',
      transactionId: json['transactionId'],
      assignedTeam: json['assignedTeam'],
      teamCommission: (json['teamCommission'] ?? 0).toDouble(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
      completedAt: (json['completedAt'] as Timestamp?)?.toDate(),
      notes: json['notes'],
    );
  }

  Booking copyWith({
    String? id,
    String? userId,
    String? userEmail,
    String? userName,
    String? customerId,
    String? plateNumber,
    String? contactNumber,
    String? vehicleType,
    DateTime? scheduledDateTime,
    List<BookingService>? services,
    DateTime? createdAt,
    String? status,
    String? paymentStatus,
    String? source,
    String? transactionId,
    String? assignedTeam,
    double? teamCommission,
    DateTime? updatedAt,
    DateTime? completedAt,
    String? notes,
  }) {
    return Booking(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      customerId: customerId ?? this.customerId,
      plateNumber: plateNumber ?? this.plateNumber,
      contactNumber: contactNumber ?? this.contactNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      services: services ?? this.services,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      source: source ?? this.source,
      transactionId: transactionId ?? this.transactionId,
      assignedTeam: assignedTeam ?? this.assignedTeam,
      teamCommission: teamCommission ?? this.teamCommission,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
    );
  }
}

class BookingManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'Bookings';

  /// Create a new booking
  static Future<String> createBooking(Booking booking) async {
    try {
      final docRef = await _firestore
          .collection(_collection)
          .add(booking.toJson());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create booking: $e');
    }
  }

  /// Get all bookings
  static Future<List<Booking>> getAllBookings() async {
    try {
      final QuerySnapshot query = await _firestore
          .collection(_collection)
          .orderBy('scheduledDateTime', descending: false)
          .get();

      return query.docs.map((doc) {
        return Booking.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get bookings: $e');
    }
  }

  /// Get bookings by status
  static Future<List<Booking>> getBookingsByStatus(String status) async {
    try {
      final QuerySnapshot query = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: status)
          .get();

      final bookings = query.docs.map((doc) {
        return Booking.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      // Sort in memory to avoid composite index requirement
      bookings.sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));

      return bookings;
    } catch (e) {
      throw Exception('Failed to get bookings by status: $e');
    }
  }

  /// Get bookings by customer
  static Future<List<Booking>> getBookingsByCustomer(String customerId) async {
    try {
      final QuerySnapshot query = await _firestore
          .collection(_collection)
          .where('customerId', isEqualTo: customerId)
          .orderBy('scheduledDateTime', descending: true)
          .get();

      return query.docs.map((doc) {
        return Booking.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get bookings by customer: $e');
    }
  }

  /// Get bookings by user email (for customer app without customerId)
  static Future<List<Booking>> getBookingsByEmail(String email) async {
    try {
      final QuerySnapshot query = await _firestore
          .collection(_collection)
          .where('userEmail', isEqualTo: email)
          .orderBy('scheduledDateTime', descending: true)
          .get();

      return query.docs.map((doc) {
        return Booking.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get bookings by email: $e');
    }
  }

  /// Update booking status
  static Future<void> updateBookingStatus(String bookingId, String status) async {
    try {
      await _firestore.collection(_collection).doc(bookingId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update booking status: $e');
    }
  }

  /// Mark booking as completed with transaction reference
  static Future<void> completeBooking({
    required String bookingId,
    required String transactionId,
    double teamCommission = 0.0,
  }) async {
    try {
      await _firestore.collection(_collection).doc(bookingId).update({
        'status': 'completed',
        'paymentStatus': 'paid',
        'transactionId': transactionId,
        'teamCommission': teamCommission,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to complete booking: $e');
    }
  }

  /// Reschedule booking
  static Future<void> rescheduleBooking(String bookingId, DateTime newDateTime) async {
    try {
      await _firestore.collection(_collection).doc(bookingId).update({
        'scheduledDateTime': Timestamp.fromDate(newDateTime),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to reschedule booking: $e');
    }
  }

  /// Get today's bookings
  static Future<List<Booking>> getTodayBookings() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final QuerySnapshot query = await _firestore
          .collection(_collection)
          .where('scheduledDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('scheduledDateTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('scheduledDateTime', descending: false)
          .get();

      return query.docs.map((doc) {
        return Booking.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get today\'s bookings: $e');
    }
  }

  /// Get upcoming bookings
  static Future<List<Booking>> getUpcomingBookings() async {
    try {
      final now = DateTime.now();

      final QuerySnapshot query = await _firestore
          .collection(_collection)
          .where('scheduledDateTime', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('scheduledDateTime', descending: false)
          .limit(20)
          .get();

      return query.docs.map((doc) {
        return Booking.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get upcoming bookings: $e');
    }
  }

  /// Link customer to existing bookings by plate number
  static Future<void> linkCustomerToBookings({
    required String customerId,
    required String plateNumber,
  }) async {
    try {
      final bookings = await _firestore
          .collection(_collection)
          .where('plateNumber', isEqualTo: plateNumber.toUpperCase())
          .where('customerId', isNull: true)
          .get();

      final batch = _firestore.batch();
      for (final doc in bookings.docs) {
        batch.update(doc.reference, {
          'customerId': customerId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to link customer to bookings: $e');
    }
  }

  /// Assign team to booking
  static Future<void> assignTeam(String bookingId, String team) async {
    try {
      await _firestore.collection(_collection).doc(bookingId).update({
        'assignedTeam': team,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to assign team: $e');
    }
  }
}
