import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

abstract class AuthRepository {
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(firebase_auth.PhoneAuthCredential) verificationCompleted,
    required Function(firebase_auth.FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  });

  Future<firebase_auth.UserCredential> signInWithCredential(
    firebase_auth.PhoneAuthCredential credential,
  );

  firebase_auth.User? getCurrentUser();

  Future<void> signOut();

  Stream<firebase_auth.User?> authStateChanges();
}
