import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../services/google_sign_in_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;

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

                      // Google Sign-In button
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _handleGoogleSignIn,
                        icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : const Icon(Icons.login, color: Colors.black),
                        label: Text(_isLoading ? "Signing in..." : "Sign in with Google"),
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
                        "Select a role after authentication",
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

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = await GoogleSignInService.signInWithGoogle();

      if (user != null) {
        if (mounted) {
          _showRoleSelector(context, user);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sign in was cancelled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showRoleSelector(BuildContext context, User user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: NetworkImage(user.photoURL ?? ''),
              child: user.photoURL == null
                ? const Icon(Icons.person, size: 30)
                : null,
            ),
            const SizedBox(height: 10),
            Text("Welcome, ${user.displayName ?? 'User'}!"),
            const SizedBox(height: 5),
            const Text(
              "Select Your Role",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.shield, color: Colors.black),
              title: const Text("Admin"),
              subtitle: const Text("Full system access"),
              onTap: () => _selectRole(context, "Admin"),
            ),
            ListTile(
              leading: const Icon(Icons.people, color: Colors.black),
              title: const Text("Staff"),
              subtitle: const Text("Employee dashboard"),
              onTap: () => _selectRole(context, "Staff"),
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.black),
              title: const Text("Customer"),
              subtitle: const Text("Book services"),
              onTap: () => _selectRole(context, "Customer"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await GoogleSignInService.signOut();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text("Sign Out"),
          ),
        ],
      ),
    );
  }

  void _selectRole(BuildContext context, String role) {
    Navigator.pop(context);
    navigateToRole(context, role);
  }
}
