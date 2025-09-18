import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GoogleSignInService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<User?> signInWithGoogle() async {
    try {
      print('Starting Google Sign-in process...');

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      print('Google sign-in result: $googleUser');

      if (googleUser == null) {
        print('User canceled the sign-in or sign-in failed');
        return null;
      }

      print('Google user obtained: ${googleUser.email}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('Authentication tokens obtained');

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      print('Firebase credential created');

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      print('Firebase sign-in successful: ${userCredential.user?.email}');

      return userCredential.user;
    } catch (e) {
      print('Error signing in with Google: $e');
      if (e.toString().contains('PlatformException')) {
        print('Platform exception details: $e');
      }
      return null;
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  static Stream<User?> get authStateChanges => _auth.authStateChanges();
}