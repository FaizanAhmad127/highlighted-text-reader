import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/firestore_datasource.dart';
import '../models/user_model.dart';

class UserRepositoryImpl implements UserRepository {
  final FirestoreDataSource _dataSource;

  UserRepositoryImpl(this._dataSource);

  @override
  Future<void> createUser(User user) async {
    final userModel = UserModel.fromEntity(user);
    await _dataSource.createUser(userModel);
  }

  @override
  Future<User?> getUserById(String id) async {
    final userModel = await _dataSource.getUserById(id);
    return userModel?.toEntity();
  }

  @override
  Stream<User?> getUserStream(String id) {
    return _dataSource
        .getUserStream(id)
        .map((userModel) => userModel?.toEntity());
  }

  @override
  Future<List<User>> getAllUsers() async {
    final userModels = await _dataSource.getAllUsers();
    return userModels.map((model) => model.toEntity()).toList();
  }

  @override
  Future<void> updateUser(User user) async {
    final userModel = UserModel.fromEntity(user);
    await _dataSource.updateUser(userModel);
  }

  @override
  Future<void> deleteUser(String id) async {
    await _dataSource.deleteUser(id);
  }

  @override
  Future<void> updateUserField(String id, String field, dynamic value) async {
    await _dataSource.updateUserField(id, field, value);
  }

  @override
  Future<void> updateTokensUsed(String id, int delta) async {
    await _dataSource.updateTokensUsed(id, delta);
  }
}
