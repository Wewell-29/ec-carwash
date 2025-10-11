import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String? id;
  final String userId;
  final String userEmail;
  final String userName;
  final String plateNumber;
  final String contactNumber;
  final DateTime selectedDateTime;
  final String date;
  final String time;
  final List<BookingService> services;
  final DateTime createdAt;
  final String status; // 'pending', 'approved', 'completed', 'cancelled'
  final String paymentStatus; // 'unpaid', 'paid'
  final String? source; // 'pos', 'booking' or null for app bookings
  final String? assignedTeam; // 'Team A', 'Team B', or null

  Booking({
    this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.plateNumber,
    required this.contactNumber,
    required this.selectedDateTime,
    required this.date,
    required this.time,
    required this.services,
    required this.createdAt,
    this.status = 'pending',
    this.paymentStatus = 'unpaid',
    this.source,
    this.assignedTeam,
  });

  double get totalAmount {
    return services.fold(0.0, (total, service) => total + service.price);
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'plateNumber': plateNumber.toUpperCase(),
      'contactNumber': contactNumber,
      'selectedDateTime': Timestamp.fromDate(selectedDateTime),
      'date': date,
      'time': time,
      'services': services.map((s) => s.toJson()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'paymentStatus': paymentStatus,
      'source': source,
      'assignedTeam': assignedTeam,
    };
  }

  factory Booking.fromJson(Map<String, dynamic> json, String docId) {
    final selectedDateTime = json['selectedDateTime'] is Timestamp
        ? (json['selectedDateTime'] as Timestamp).toDate()
        : DateTime.parse(json['selectedDateTime'] ?? DateTime.now().toIso8601String());

    final createdAt = json['createdAt'] is Timestamp
        ? (json['createdAt'] as Timestamp).toDate()
        : DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String());

    return Booking(
      id: docId,
      userId: json['userId'] ?? '',
      userEmail: json['userEmail'] ?? '',
      userName: json['userName'] ?? '',
      plateNumber: json['plateNumber'] ?? '',
      contactNumber: json['contactNumber'] ?? '',
      selectedDateTime: selectedDateTime,
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      services: (json['services'] as List<dynamic>? ?? [])
          .map((s) => BookingService.fromJson(s as Map<String, dynamic>))
          .toList(),
      createdAt: createdAt,
      status: json['status'] ?? 'pending',
      paymentStatus: json['paymentStatus'] ?? 'unpaid',
      source: json['source'],
      assignedTeam: json['assignedTeam'],
    );
  }

  Booking copyWith({
    String? id,
    String? userId,
    String? userEmail,
    String? userName,
    String? plateNumber,
    String? contactNumber,
    DateTime? selectedDateTime,
    String? date,
    String? time,
    List<BookingService>? services,
    DateTime? createdAt,
    String? status,
    String? paymentStatus,
    String? source,
    String? assignedTeam,
  }) {
    return Booking(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      plateNumber: plateNumber ?? this.plateNumber,
      contactNumber: contactNumber ?? this.contactNumber,
      selectedDateTime: selectedDateTime ?? this.selectedDateTime,
      date: date ?? this.date,
      time: time ?? this.time,
      services: services ?? this.services,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      source: source ?? this.source,
      assignedTeam: assignedTeam ?? this.assignedTeam,
    );
  }
}

class BookingService {
  final String serviceCode;
  final String serviceName;
  final String vehicleType;
  final double price;

  BookingService({
    required this.serviceCode,
    required this.serviceName,
    required this.vehicleType,
    required this.price,
  });

  Map<String, dynamic> toJson() {
    return {
      'serviceCode': serviceCode,
      'serviceName': serviceName,
      'vehicleType': vehicleType,
      'price': price,
    };
  }

  factory BookingService.fromJson(Map<String, dynamic> json) {
    return BookingService(
      serviceCode: json['serviceCode'] ?? '',
      serviceName: json['serviceName'] ?? '',
      vehicleType: json['vehicleType'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
    );
  }
}

class BookingManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'Bookings';

  static Future<List<Booking>> getAllBookings() async {
    try {
      final QuerySnapshot query = await _firestore
          .collection(_collection)
          .orderBy('selectedDateTime', descending: false)
          .get();

      return query.docs.map((doc) {
        return Booking.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get bookings: $e');
    }
  }

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
      bookings.sort((a, b) => a.selectedDateTime.compareTo(b.selectedDateTime));

      return bookings;
    } catch (e) {
      throw Exception('Failed to get bookings by status: $e');
    }
  }

  static Future<void> updateBookingStatus(String bookingId, String status) async {
    try {
      await _firestore.collection(_collection).doc(bookingId).update({
        'status': status,
      });
    } catch (e) {
      throw Exception('Failed to update booking status: $e');
    }
  }

  static Future<void> rescheduleBooking(String bookingId, DateTime newDateTime, String newDate, String newTime) async {
    try {
      await _firestore.collection(_collection).doc(bookingId).update({
        'selectedDateTime': Timestamp.fromDate(newDateTime),
        'date': newDate,
        'time': newTime,
      });
    } catch (e) {
      throw Exception('Failed to reschedule booking: $e');
    }
  }

  static Future<List<Booking>> getTodayBookings() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final QuerySnapshot query = await _firestore
          .collection(_collection)
          .where('selectedDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('selectedDateTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('selectedDateTime', descending: false)
          .get();

      return query.docs.map((doc) {
        return Booking.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get today\'s bookings: $e');
    }
  }

  static Future<List<Booking>> getUpcomingBookings() async {
    try {
      final now = DateTime.now();

      final QuerySnapshot query = await _firestore
          .collection(_collection)
          .where('selectedDateTime', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('selectedDateTime', descending: false)
          .limit(20)
          .get();

      return query.docs.map((doc) {
        return Booking.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get upcoming bookings: $e');
    }
  }
}