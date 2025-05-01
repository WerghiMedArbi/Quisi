import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthController {
  final auth.FirebaseAuth _firebaseAuth = auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Auth state stream
  Stream<User?> get userStream => _firebaseAuth.authStateChanges().map(
    (auth.User? firebaseUser) => firebaseUser != null 
        ? User.fromFirebaseUser(firebaseUser) 
        : null
  );

  // Current user
  User? get currentUser {
    final firebaseUser = _firebaseAuth.currentUser;
    return firebaseUser != null ? User.fromFirebaseUser(firebaseUser) : null;
  }

  // Sign in with email and password
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user != null) {
        await _updateUserData(userCredential.user!);
        return User.fromFirebaseUser(userCredential.user!);
      }
      return null;
    } catch (e) {
      print('Error signing in with email and password: $e');
      rethrow;
    }
  }

  // Sign up with email and password
  Future<User?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user != null) {
        await _updateUserData(userCredential.user!);
        return User.fromFirebaseUser(userCredential.user!);
      }
      return null;
    } catch (e) {
      print('Error signing up with email and password: $e');
      rethrow;
    }
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _updateUserData(userCredential.user!);
        return User.fromFirebaseUser(userCredential.user!);
      }
      return null;
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([
        _firebaseAuth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  // Update user data in Firestore
  Future<void> _updateUserData(auth.User firebaseUser) async {
    final user = User.fromFirebaseUser(firebaseUser);
    await _firestore.collection('users').doc(user.id).set(
      user.toMap(),
      SetOptions(merge: true),
    );
  }

  // Get user data from Firestore
  Future<User?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.exists ? User.fromFirestore(doc) : null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }
} 