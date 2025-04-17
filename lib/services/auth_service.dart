import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:math';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  // Stream to listen for auth changes
  Stream<User?> get user => _auth.authStateChanges();
  
  // Sign in with email/password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      // Special case for admin credentials
      if (email == 'admin' && password == 'admin') {
        // Use a fixed admin email that you've already registered in Firebase
        UserCredential result = await _auth.signInWithEmailAndPassword(
          email: 'admin@quizapp.com', 
          password: 'admin123'
        );
        return result.user;
      } else {
        // Regular user login
        UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, 
          password: password
        );
        return result.user;
      }
    } on FirebaseAuthException catch (e) {
      print('Sign in error: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'user-not-found':
          throw 'No user found with this email.';
        case 'wrong-password':
          throw 'Wrong password provided.';
        case 'invalid-email':
          throw 'Invalid email address.';
        case 'user-disabled':
          throw 'This user account has been disabled.';
        default:
          throw 'Authentication failed: ${e.message}';
      }
    } catch (e) {
      print('Sign in error: $e');
      throw 'An error occurred during sign in.';
    }
  }
  
  // Sign up with email/password
  Future<User?> signUpWithEmail(
    String email, 
    String password, {
    String? firstName,
    String? lastName,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      // Update the user's display name if provided
      if (firstName != null && lastName != null) {
        await result.user?.updateDisplayName('$firstName $lastName');
        
        // You might also want to store this in Firestore if you're using it
        // await FirebaseFirestore.instance.collection('users').doc(result.user!.uid).set({
        //   'firstName': firstName,
        //   'lastName': lastName,
        //   'email': email,
        //   'createdAt': DateTime.now(),
        // });
      }
      
      return result.user;
    } on FirebaseAuthException catch (e) {
      print('Sign up error: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'weak-password':
          throw 'The password provided is too weak.';
        case 'email-already-in-use':
          throw 'An account already exists for this email.';
        case 'invalid-email':
          throw 'Invalid email address.';
        default:
          throw 'Registration failed: ${e.message}';
      }
    } catch (e) {
      print('Sign up error: $e');
      throw 'An error occurred during registration.';
    }
  }
  
  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web platform - Admin authentication
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({
          'client_id': '841287443686-peovshgl11c890u1fi5iahio8pd4sri2.apps.googleusercontent.com',
          'prompt': 'select_account'
        });
        return await _auth.signInWithPopup(googleProvider);
      } else {
        // Mobile platform - Anonymous authentication for participants
        return await _auth.signInAnonymously();
      }
    } catch (e) {
      print('Error during authentication: $e');
      return null;
    }
  }
  
  // Sign in anonymously
  Future<User?> signInAnonymously() async {
    try {
      UserCredential result = await _auth.signInAnonymously();
      User? user = result.user;
      
      // Generate a random profile picture (using a placeholder service)
      // In a real app, you might generate an avatar or use a library for this
      int randomSeed = Random().nextInt(1000);
      String avatarUrl = 'https://api.dicebear.com/6.x/avataaars/svg?seed=$randomSeed';
      
      // Set a random display name
      await user?.updateProfile(photoURL: avatarUrl);
      
      return user;
    } catch (e) {
      print('Anonymous sign in error: $e');
      throw 'Failed to sign in anonymously. Please try again.';
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      if (kIsWeb) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }
  
  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Check if user is signed in anonymously
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  // Check if user is admin (web only)
  bool isAdmin() {
    final user = currentUser;
    return kIsWeb && user != null && !user.isAnonymous;
  }

  // Check if user is participant (mobile only)
  bool isParticipant() {
    final user = currentUser;
    return !kIsWeb && user != null && user.isAnonymous;
  }
}