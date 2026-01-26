// This is a simple test script to verify authentication functionality
// Place this in lib/utils/auth_tester.dart

import 'package:firebase_auth/firebase_auth.dart';

class AuthTester {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Method to test authentication status
  Future<void> testAuthStatus() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        print('User is authenticated: ${user.email}');
        print('User ID: ${user.uid}');
      } else {
        print('No user is currently authenticated');
      }
    } catch (e) {
      print('Error checking auth status: $e');
    }
  }

  // Method to test sign out
  Future<void> testSignOut() async {
    try {
      await _auth.signOut();
      print('Successfully signed out');
    } catch (e) {
      print('Error signing out: $e');
    }
  }
  
  // Method to get current user info
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}