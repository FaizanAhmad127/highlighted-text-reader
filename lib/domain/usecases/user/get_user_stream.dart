import '../../entities/user.dart';
import '../../repositories/user_repository.dart';

class GetUserStreamUseCase {
  final UserRepository _userRepository;

  GetUserStreamUseCase(this._userRepository);

  Stream<User?> call(String userId) {
    return _userRepository.getUserStream(userId);
  }
}
