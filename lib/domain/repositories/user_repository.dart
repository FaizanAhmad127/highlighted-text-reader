import '../entities/user.dart';

abstract class UserRepository {
  Future<void> createUser(User user);
  Future<User?> getUserById(String id);
  Stream<User?> getUserStream(String id);
  Future<List<User>> getAllUsers();
  Future<void> updateUser(User user);
  Future<void> deleteUser(String id);
  Future<void> updateUserField(String id, String field, dynamic value);
  Future<void> updateTokensUsed(String id, int delta);
}
