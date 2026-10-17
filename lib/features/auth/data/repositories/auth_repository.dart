import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/models/app_user.dart';

class NonVitEmailException implements Exception {
  final String message;
  const NonVitEmailException([this.message = 'Access restricted: Only VIT students (@vitstudent.ac.in) are permitted to sign in.']);

  @override
  String toString() => message;
}

abstract class IAuthRepository {
  Stream<AppUser?> get authStateChanges;
  AppUser? get currentUser;
  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  });
  Future<AppUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  });
  Future<AppUser> signInWithGoogle();
  Future<void> sendEmailVerification();
  Future<void> sendPasswordResetEmail(String email);
  Future<void> signOut();
}

class FirebaseAuthRepository implements IAuthRepository {
  final fb.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  static const String vitDomain = '@vitstudent.ac.in';

  FirebaseAuthRepository({
    fb.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: ['email', 'profile'],
              hostedDomain: 'vitstudent.ac.in',
            );

  bool _isVitEmail(String email) {
    return email.trim().toLowerCase().endsWith(vitDomain);
  }

  @override
  Stream<AppUser?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map((user) {
      if (user == null) return null;
      return AppUser.fromFirebaseUser(user);
    });
  }

  @override
  AppUser? get currentUser {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    return AppUser.fromFirebaseUser(user);
  }

  @override
  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!_isVitEmail(cleanEmail)) {
      throw const NonVitEmailException();
    }

    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw Exception('Failed to sign in: No user returned');
    }

    return AppUser.fromFirebaseUser(user);
  }

  @override
  Future<AppUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!_isVitEmail(cleanEmail)) {
      throw const NonVitEmailException();
    }

    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw Exception('Failed to register: No user returned');
    }

    // Update display name
    await user.updateDisplayName(displayName.trim());
    await user.reload();

    // Send email verification to VIT email
    try {
      await user.sendEmailVerification();
    } catch (_) {}

    final updatedUser = _firebaseAuth.currentUser ?? user;
    return AppUser.fromFirebaseUser(updatedUser);
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    // Trigger Google Sign In flow
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google sign-in was cancelled by user');
    }

    // Verify VIT student email restriction
    final email = googleUser.email.trim().toLowerCase();
    if (!_isVitEmail(email)) {
      await _googleSignIn.signOut();
      throw const NonVitEmailException();
    }

    // Obtain auth details
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final fb.OAuthCredential credential = fb.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final fb.UserCredential userCredential =
        await _firebaseAuth.signInWithCredential(credential);

    final user = userCredential.user;
    if (user == null) {
      throw Exception('Google Sign-In failed to link with Firebase');
    }

    return AppUser.fromFirebaseUser(user);
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!_isVitEmail(cleanEmail)) {
      throw const NonVitEmailException();
    }
    await _firebaseAuth.sendPasswordResetEmail(email: cleanEmail);
  }

  @override
  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
}
