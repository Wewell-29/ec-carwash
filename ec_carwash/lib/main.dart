import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // 👈 make sure you have this file (flutterfire configure)
import 'theme.dart';
import 'screens/login_page.dart';
import 'screens/Admin/admin_staff_home.dart';
import 'screens/Customer/customer_home.dart';
import 'data_models/inventory_data.dart';
import 'data_models/services_data.dart';
import 'services/local_notification_service.dart';
import 'services/firebase_messaging_service.dart';
import 'services/fcm_token_manager.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // 👈 required for web
  );

  // Initialize inventory data if Firestore collection is empty
  await InventoryManager.initializeWithSampleData();

  // Initialize services data if Firestore collection is empty
  await ServicesManager.initializeWithSampleData();

  // Initialize notification services (only for mobile platforms)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await LocalNotificationService.initialize();
    await FirebaseMessagingService.initialize();
    await FCMTokenManager.initializeToken();
  }

  runApp(const ECCarwashApp());
}

class ECCarwashApp extends StatelessWidget {
  const ECCarwashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EC Carwash',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginPage(),
    );
  }
}

/// Simplified role-based navigation
void navigateToRole(BuildContext context) {
  if (kIsWeb) {
    // 👈 Web users = Admin
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AdminStaffHome()),
    );
  } else if (Platform.isAndroid) {
    // 👈 Android users = Customer
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CustomerHome()),
    );
  } else {
    // 👈 Default fallback (iOS/Desktop) → Staff
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AdminStaffHome()),
    );
  }
}
