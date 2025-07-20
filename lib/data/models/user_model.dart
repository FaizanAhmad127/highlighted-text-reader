import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.name,
    required super.phoneNumber,
    required super.gender,
    required super.tokensUsed,
  });

  // Convert a UserModel object into a Map object
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'gender': gender,
      'tokensUsed': tokensUsed,
    };
  }

  // Create a UserModel object from a Map object
  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      gender: map['gender'] ?? '',
      tokensUsed: map['tokensUsed'] ?? 0,
    );
  }

  // Convert from domain entity
  factory UserModel.fromEntity(User user) {
    return UserModel(
      id: user.id,
      name: user.name,
      phoneNumber: user.phoneNumber,
      gender: user.gender,
      tokensUsed: user.tokensUsed,
    );
  }

  // Convert to domain entity
  User toEntity() {
    return User(
      id: id,
      name: name,
      phoneNumber: phoneNumber,
      gender: gender,
      tokensUsed: tokensUsed,
    );
  }
}
