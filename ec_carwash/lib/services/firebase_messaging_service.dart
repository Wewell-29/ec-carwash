import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'local_notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data_models/notification_data.dart';

/// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Handling a background message: ${message.messageId}');
  }

  // Display notification even when app is in background
  if (message.notification != null) {
    await LocalNotificationService.showNotification(
      id: message.hashCode,
      title: message.notification!.title ?? 'EC Carwash',
      body: message.notification!.body ?? 'You have a new notification',
      payload: message.data.toString(),
    );
  }
}

/// Service to handle Firebase Cloud Messaging
class FirebaseMessagingService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  /// Initialize Firebase Messaging
  static Future<void> initialize() async {
    try {
      // Request permission for notifications
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        if (kDebugMode) {
          print('User granted FCM permission');
        }

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle background messages
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

        // Handle notification taps when app is in background
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

        // Check if app was opened from a terminated state via notification
        RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageOpenedApp(initialMessage);
        }
      } else {
        if (kDebugMode) {
          print('User declined FCM permission');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing Firebase Messaging: $e');
      }
    }
  }

  /// Handle foreground messages (when app is open)
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      print('Received foreground message: ${message.messageId}');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
      print('Data: ${message.data}');
    }

    // Show local notification when app is in foreground
    if (message.notification != null) {
      await LocalNotificationService.showNotification(
        id: message.hashCode,
        title: message.notification!.title ?? 'EC Carwash',
        body: message.notification!.body ?? 'You have a new notification',
        payload: message.data.toString(),
      );
    }

    // Persist to Firestore for in-app notifications list
    try {
      final email = FirebaseAuth.instance.currentUser?.email;
      if (email != null) {
        await NotificationManager.createNotification(
          userId: email,
          title: message.notification?.title ?? 'EC Carwash',
          message: message.notification?.body ?? 'You have a new notification',
          type: (message.data['type'] ?? 'general').toString(),
          metadata: message.data.isEmpty ? null : Map<String, dynamic>.from(message.data),
        );
      }
    } catch (_) {}
  }

  /// Handle notification tap when app is in background or terminated
  static void _handleMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      print('Notification opened app: ${message.messageId}');
      print('Data: ${message.data}');
    }

    // Persist to Firestore as the user likely expects to see it in the app list
    try {
      final email = FirebaseAuth.instance.currentUser?.email;
      if (email != null) {
        NotificationManager.createNotification(
          userId: email,
          title: message.notification?.title ?? 'EC Carwash',
          message: message.notification?.body ?? 'You have a new notification',
          type: (message.data['type'] ?? 'general').toString(),
          metadata: message.data.isEmpty ? null : Map<String, dynamic>.from(message.data),
        );
      }
    } catch (_) {}

    // Navigate to specific screen based on notification data
    // You can add custom navigation logic here
    // For example:
    // if (message.data['type'] == 'booking_confirmed') {
    //   // Navigate to bookings screen
    // }
  }

  /// Subscribe to a topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      if (kDebugMode) {
        print('Subscribed to topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error subscribing to topic: $e');
      }
    }
  }

  /// Unsubscribe from a topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      if (kDebugMode) {
        print('Unsubscribed from topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error unsubscribing from topic: $e');
      }
    }
  }
}
