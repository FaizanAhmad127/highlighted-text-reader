import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../repositories/auth_repository.dart';

class VerifyPhoneNumberUseCase {
  final AuthRepository _authRepository;

  VerifyPhoneNumberUseCase(this._authRepository);

  Future<void> call({
    required String phoneNumber,
    required Function(firebase_auth.PhoneAuthCredential) verificationCompleted,
    required Function(firebase_auth.FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    await _authRepository.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }
}
