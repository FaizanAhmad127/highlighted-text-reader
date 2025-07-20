class User {
  final String id;
  final String name;
  final String phoneNumber;
  final String gender;
  final int tokensUsed;

  const User({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.gender,
    required this.tokensUsed,
  });

  User copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? gender,
    int? tokensUsed,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      gender: gender ?? this.gender,
      tokensUsed: tokensUsed ?? this.tokensUsed,
    );
  }
}
