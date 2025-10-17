import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationData {
  final String? id;
  final String userId; // email of the user
  final String title;
  final String message;
  final String type; // 'booking_approved', 'booking_completed', 'general', etc.
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata; // Additional data like bookingId, etc.

  NotificationData({
    this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    required this.createdAt,
    this.metadata,
  });

  factory NotificationData.fromJson(Map<String, dynamic> json, String id) {
    return NotificationData(
      id: id,
      userId: json['userId'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'general',
      isRead: json['isRead'] ?? false,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'metadata': metadata,
    };
  }

  NotificationData copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? type,
    bool? isRead,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationData(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

class NotificationManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'Notifications';

  // Get all notifications for a user
  static Stream<List<NotificationData>> getUserNotifications(String userEmail) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userEmail)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationData.fromJson(doc.data(), doc.id))
            .toList());
  }

  // Get unread count
  static Stream<int> getUnreadCount(String userEmail) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userEmail)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    await _firestore.collection(_collection).doc(notificationId).update({
      'isRead': true,
    });
  }

  // Mark all notifications as read
  static Future<void> markAllAsRead(String userEmail) async {
    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userEmail)
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  // Create a new notification
  static Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? metadata,
  }) async {
    final notification = NotificationData(
      userId: userId,
      title: title,
      message: message,
      type: type,
      createdAt: DateTime.now(),
      metadata: metadata,
    );

    await _firestore.collection(_collection).add(notification.toJson());
  }

  // Delete a notification
  static Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection(_collection).doc(notificationId).delete();
  }

  // Delete all notifications for a user
  static Future<void> deleteAllNotifications(String userEmail) async {
    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userEmail)
        .get();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
