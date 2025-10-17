import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to manage FCM tokens for push notifications
class FCMTokenManager {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Initialize FCM token and save it to Firestore
  static Future<void> initializeToken() async {
    try {
      // Request notification permissions
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
        print('User granted permission');

        // Get the FCM token
        String? token = await _firebaseMessaging.getToken();

        if (token != null) {
          await saveTokenToFirestore(token);

          // Listen for token refresh
          _firebaseMessaging.onTokenRefresh.listen((newToken) {
            saveTokenToFirestore(newToken);
          });
        }
      } else {
        print('User declined or has not accepted permission');
      }
    } catch (e) {
      print('Error initializing FCM token: $e');
    }
  }

  /// Save the FCM token to Firestore under the user's document
  static Future<void> saveTokenToFirestore(String token) async {
    try {
      User? user = _auth.currentUser;

      if (user != null) {
        await _firestore.collection('Users').doc(user.uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'email': user.email,
          'userId': user.uid,
        }, SetOptions(merge: true));

        print('FCM Token saved to Firestore for user: ${user.uid}');
      }
    } catch (e) {
      print('Error saving token to Firestore: $e');
    }
  }

  /// Delete the FCM token from Firestore (call on logout)
  static Future<void> deleteTokenFromFirestore() async {
    try {
      User? user = _auth.currentUser;

      if (user != null) {
        await _firestore.collection('Users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
        });

        // Delete the token from FCM
        await _firebaseMessaging.deleteToken();

        print('FCM Token deleted from Firestore for user: ${user.uid}');
      }
    } catch (e) {
      print('Error deleting token from Firestore: $e');
    }
  }

  /// Get the current FCM token
  static Future<String?> getToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }
}
