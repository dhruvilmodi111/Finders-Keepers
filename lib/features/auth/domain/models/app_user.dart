import 'package:firebase_auth/firebase_auth.dart' as fb;

class AppUser {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final bool isEmailVerified;
  final bool isVitStudent;

  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.isEmailVerified,
    required this.isVitStudent,
  });

  factory AppUser.fromFirebaseUser(fb.User user) {
    final email = user.email ?? '';
    final isVit = email.toLowerCase().endsWith('@vitstudent.ac.in');

    return AppUser(
      id: user.uid,
      email: email,
      displayName: user.displayName?.isNotEmpty == true
          ? user.displayName!
          : email.split('@').first,
      photoUrl: user.photoURL,
      isEmailVerified: user.emailVerified,
      isVitStudent: isVit,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'isEmailVerified': isEmailVerified,
      'isVitStudent': isVitStudent,
    };
  }
}
