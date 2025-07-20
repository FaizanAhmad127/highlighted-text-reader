import '../../repositories/user_repository.dart';

class UpdateTokensUsedUseCase {
  final UserRepository _userRepository;

  UpdateTokensUsedUseCase(this._userRepository);

  Future<void> call(String userId, int delta) async {
    await _userRepository.updateTokensUsed(userId, delta);
  }
}
