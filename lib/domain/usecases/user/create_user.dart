import '../../entities/user.dart';
import '../../repositories/user_repository.dart';

class CreateUserUseCase {
  final UserRepository _userRepository;

  CreateUserUseCase(this._userRepository);

  Future<void> call(User user) async {
    await _userRepository.createUser(user);
  }
}
