import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.yellow, Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 400, // 👈 limits card width
              ),
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width < 500 ? 24 : 36,
                    vertical: 40,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo / Placeholder
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.yellow[700],
                        child: const Icon(
                          Icons.local_car_wash,
                          color: Colors.black,
                          size: 50,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // App Title
                      Text(
                        "EC Carwash",
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Quick & Easy Carwash Services",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 30),

                      // Fake Google Sign-In button (for now)
                      ElevatedButton.icon(
                        onPressed: () => _showRoleSelector(context),
                        icon: const Icon(Icons.login, color: Colors.black),
                        label: const Text("Sign in with Google"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellow[700],
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 50),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      Text(
                        "Demo Mode: Select a role after login",
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Temporary role selector dialog (since Firebase not yet connected)
  void _showRoleSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Role"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.shield, color: Colors.black),
              title: const Text("Admin"),
              onTap: () => _selectRole(context, "Admin"),
            ),
            ListTile(
              leading: const Icon(Icons.people, color: Colors.black),
              title: const Text("Staff"),
              onTap: () => _selectRole(context, "Staff"),
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.black),
              title: const Text("Customer"),
              onTap: () => _selectRole(context, "Customer"),
            ),
          ],
        ),
      ),
    );
  }

  void _selectRole(BuildContext context, String role) {
    Navigator.pop(context); // close dialog
    navigateToRole(context, role); // go to dashboard
  }
}
