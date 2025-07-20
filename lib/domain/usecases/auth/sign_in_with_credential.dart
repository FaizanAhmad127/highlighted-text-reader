import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../repositories/auth_repository.dart';

class SignInWithCredentialUseCase {
  final AuthRepository _authRepository;

  SignInWithCredentialUseCase(this._authRepository);

  Future<firebase_auth.UserCredential> call(
    firebase_auth.PhoneAuthCredential credential,
  ) async {
    return await _authRepository.signInWithCredential(credential);
  }
}
