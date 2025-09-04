import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/login_page.dart';
import 'screens/admin_staff_home.dart';
import 'screens/customer_home.dart';

void main() {
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

// Fake role-based navigation for now
void navigateToRole(BuildContext context, String role) {
  if (role == "Admin") {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AdminStaffHome(role: "Admin")),
    );
  } else if (role == "Staff") {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AdminStaffHome(role: "Staff")),
    );
  } else {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CustomerHome()),
    );
  }
}
