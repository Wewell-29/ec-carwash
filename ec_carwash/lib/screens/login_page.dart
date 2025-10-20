import 'package:flutter/foundation.dart'; // 👈 for kIsWeb
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/google_sign_in_service.dart';
import 'Admin/admin_staff_home.dart';
import 'Customer/customer_home.dart';

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
              constraints: const BoxConstraints(maxWidth: 400),
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
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.yellow[700],
                        child: ClipOval(
                          child: Image.asset(
                            "assets/images/new_logo.png",
                            fit: BoxFit.cover,
                            width: 90,
                            height: 90,
                          ),
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
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _handleGoogleSignIn,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.black,
                                  ),
                                ),
                              )
                            : const Icon(Icons.login, color: Colors.black),
                        label: Text(
                          _isLoading ? "Signing in..." : "Sign in with Google",
                        ),
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
    setState(() => _isLoading = true);

    try {
      final User? user = await GoogleSignInService.signInWithGoogle();

      if (user != null && mounted) {
        if (kIsWeb) {
          // 👉 On Web → Admin/Staff Home
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminStaffHome()),
          );
        } else {
          // 👉 On Android/iOS → Customer Home
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CustomerHome()),
          );
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
        String errorMessage = 'Sign in failed';

        // Parse the error to provide helpful messages
        final errorString = e.toString().toLowerCase();

        if (errorString.contains('network')) {
          errorMessage = 'Network error. Please check your internet connection.';
        } else if (errorString.contains('com.google.android.gms') ||
                   errorString.contains('google play services')) {
          errorMessage = 'Google Play Services not available. Please install it.';
        } else if (errorString.contains('10:') || errorString.contains('sign_in_failed')) {
          errorMessage = 'Sign in configuration error. Please contact support.';
        } else if (errorString.contains('cancelled') || errorString.contains('cancel')) {
          errorMessage = 'Sign in was cancelled';
        } else if (errorString.contains('account-exists-with-different-credential')) {
          errorMessage = 'This email is already registered with a different method.';
        } else if (errorString.contains('invalid-credential')) {
          errorMessage = 'Invalid credentials. Please try again.';
        } else {
          // Show the actual error for debugging
          errorMessage = 'Sign in failed: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
