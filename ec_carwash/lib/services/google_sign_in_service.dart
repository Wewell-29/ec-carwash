import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GoogleSignInService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<User?> signInWithGoogle() async {
    try {
      print('Starting Google Sign-in process...');

      if (kIsWeb) {
        // ✅ Web flow (no serverClientId!)
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        final UserCredential userCredential = await _auth.signInWithPopup(
          googleProvider,
        );

        print(
          'Firebase sign-in successful (web): ${userCredential.user?.email}',
        );
        return userCredential.user;
      } else {
        // ✅ Android/iOS/Desktop flow
        final GoogleSignIn googleSignIn = GoogleSignIn(
          scopes: ['email'],
          serverClientId:
              '14839235089-an3b18j0b8039dnmm0at8jermsshf9e8.apps.googleusercontent.com',
        );

        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          print('User canceled sign-in');
          return null;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential = await _auth.signInWithCredential(
          credential,
        );

        print(
          'Firebase sign-in successful (mobile/desktop): ${userCredential.user?.email}',
        );
        return userCredential.user;
      }
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      await GoogleSignIn().signOut();
    }
  }

  static User? getCurrentUser() => _auth.currentUser;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();
}
