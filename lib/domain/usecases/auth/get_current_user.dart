import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../repositories/auth_repository.dart';

class GetCurrentUserUseCase {
  final AuthRepository _authRepository;

  GetCurrentUserUseCase(this._authRepository);

  firebase_auth.User? call() {
    return _authRepository.getCurrentUser();
  }
}
