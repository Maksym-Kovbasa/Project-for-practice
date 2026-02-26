import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
  });

  final String id;
  final String username;
  final String email;
}

class FirestoreAuthService {
  FirestoreAuthService._();

  static final FirestoreAuthService instance = FirestoreAuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  Future<AuthUser> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final usernameLower = username.toLowerCase();
    final emailLower = email.toLowerCase();

    final existingUsername = await _users
        .where('usernameLower', isEqualTo: usernameLower)
        .limit(1)
        .get();
    if (existingUsername.docs.isNotEmpty) {
      throw AuthException('Username already exists.');
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user?.uid;
      if (uid == null) {
        throw AuthException('Failed to create account.');
      }

      await _users.doc(uid).set({
        'username': username,
        'usernameLower': usernameLower,
        'email': email,
        'emailLower': emailLower,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return AuthUser(
        id: uid,
        username: username,
        email: email,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  Future<AuthUser> login({
    required String username,
    required String password,
  }) async {
    final loginKey = username.trim();
    if (loginKey.isEmpty) {
      throw AuthException('Username or email is required.');
    }

    final email = loginKey.contains('@')
        ? loginKey
        : await _emailForUsername(loginKey);
    if (email == null) {
      throw AuthException('Invalid username or password.');
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user?.uid;
      if (uid == null) {
        throw AuthException('Invalid username or password.');
      }

      final userDoc = await _users.doc(uid).get();
      final data = userDoc.data() ?? <String, dynamic>{};
      return AuthUser(
        id: uid,
        username: data['username'] as String? ?? loginKey,
        email: data['email'] as String? ?? email,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  Future<String?> _emailForUsername(String username) async {
    final snapshot = await _users
        .where('usernameLower', isEqualTo: username.toLowerCase())
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return snapshot.docs.first.data()['email'] as String?;
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Email is already in use.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid username or password.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
