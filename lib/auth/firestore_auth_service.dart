import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:project/utils/error_logger.dart';

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
  bool _googleInitialized = false;
  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');
  CollectionReference<Map<String, dynamic>> get _usernames =>
      FirebaseFirestore.instance.collection('usernames');

  Future<AuthUser> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final usernameLower = username.toLowerCase();
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user?.uid;
      if (uid == null) {
        throw AuthException('Failed to create account.');
      }

      try {
        await _createProfile(
          uid: uid,
          username: username,
          email: email,
        );
      } on AuthException {
        await _safeDeleteCurrentUser();
        rethrow;
      } on FirebaseException {
        await _safeDeleteCurrentUser();
        throw AuthException('Unable to save profile. Please try again.');
      }

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

      final data = await _getOrCreateProfileFromAuthUser(
        uid: uid,
        email: email,
      );
      return AuthUser(
        id: uid,
        username: data['username'] as String? ?? loginKey,
        email: data['email'] as String? ?? email,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  Future<AuthUser> signInWithGoogle() async {
    try {
      final googleUser = await _authenticateWithGoogle();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        debugPrint('Google sign-in: Firebase returned null user.');
        await ErrorLogger.append('Google sign-in: Firebase returned null user.');
        throw AuthException('Google sign-in failed.');
      }

      final data = await _getOrCreateProfileFromAuthUser(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
      );

      return AuthUser(
        id: user.uid,
        username: data['username'] as String? ?? 'user',
        email: data['email'] as String? ?? (user.email ?? ''),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Google sign-in: FirebaseAuthException code=${e.code} message=${e.message}',
      );
      await ErrorLogger.append(
        'Google sign-in: FirebaseAuthException code=${e.code} message=${e.message}',
      );
      throw AuthException(_mapAuthError(e));
    } catch (e, stack) {
      debugPrint('Google sign-in: unexpected error $e');
      debugPrint('$stack');
      await ErrorLogger.append('Google sign-in: unexpected error $e');
      rethrow;
    }
  }

  Future<GoogleSignInAccount> _authenticateWithGoogle() async {
    if (!_googleInitialized) {
      debugPrint('Google sign-in: initializing GoogleSignIn.');
      await GoogleSignIn.instance.initialize();
      _googleInitialized = true;
    }
    try {
      debugPrint('Google sign-in: starting GoogleSignIn.authenticate().');
      return await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      debugPrint(
        'Google sign-in: GoogleSignInException code=${e.code} message=${e.description}',
      );
      await ErrorLogger.append(
        'Google sign-in: GoogleSignInException code=${e.code} message=${e.description}',
      );
      throw AuthException(_mapGoogleError(e));
    } catch (e, stack) {
      debugPrint('Google sign-in: unexpected error $e');
      debugPrint('$stack');
      await ErrorLogger.append('Google sign-in: unexpected error $e');
      rethrow;
    }
  }

  String _mapGoogleError(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Google sign-in cancelled.';
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google sign-in is not configured correctly.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google sign-in UI is unavailable.';
      case GoogleSignInExceptionCode.interrupted:
        return 'Google sign-in was interrupted. Try again.';
      case GoogleSignInExceptionCode.userMismatch:
        return 'Google sign-in user mismatch.';
      case GoogleSignInExceptionCode.unknownError:
      default:
        return 'Google sign-in failed. Please try again.';
    }
  }

  Future<Map<String, dynamic>> _getOrCreateProfileFromAuthUser({
    required String uid,
    required String? email,
    String? displayName,
  }) async {
    final doc = await _users.doc(uid).get();
    if (doc.exists) {
      return doc.data() ?? <String, dynamic>{};
    }

    final resolvedEmail = email ?? '';
    final base = _usernameBase(displayName, resolvedEmail);
    for (var i = 0; i < 5; i += 1) {
      final suffix =
          i == 0 ? '' : '${DateTime.now().millisecondsSinceEpoch % 10000}';
      final candidate = '$base$suffix';
      try {
        await _createProfile(
          uid: uid,
          username: candidate,
          email: resolvedEmail,
        );
        return {
          'username': candidate,
          'email': resolvedEmail,
        };
      } on AuthException {
        continue;
      } on FirebaseException {
        throw AuthException('Unable to save profile. Please try again.');
      }
    }
    throw AuthException('Unable to generate username. Try again.');
  }

  Future<void> _createProfile({
    required String uid,
    required String username,
    required String email,
  }) async {
    final usernameLower = username.toLowerCase();
    await FirebaseFirestore.instance.runTransaction((txn) async {
      final usernameDoc = _usernames.doc(usernameLower);
      final snapshot = await txn.get(usernameDoc);
      if (snapshot.exists) {
        throw AuthException('Username already exists.');
      }

      txn.set(usernameDoc, {
        'uid': uid,
        'username': username,
        'createdAt': FieldValue.serverTimestamp(),
      });
      txn.set(_users.doc(uid), {
        'username': username,
        'usernameLower': usernameLower,
        'email': email,
        'emailLower': email.toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<String?> _emailForUsername(String username) async {
    final usernameDoc = await _usernames
        .doc(username.toLowerCase())
        .get();
    if (!usernameDoc.exists) {
      return null;
    }
    final uid = usernameDoc.data()?['uid'] as String?;
    if (uid == null) {
      return null;
    }
    final userDoc = await _users.doc(uid).get();
    return userDoc.data()?['email'] as String?;
  }

  String _usernameBase(String? displayName, String? email) {
    final source = (displayName?.trim().isNotEmpty ?? false)
        ? displayName!
        : (email?.split('@').first ?? 'user');
    final normalized = source
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    return normalized.isEmpty ? 'user' : normalized;
  }

  Future<void> _safeDeleteCurrentUser() async {
    try {
      await _auth.currentUser?.delete();
    } catch (_) {}
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
