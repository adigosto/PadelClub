import 'package:padelclub_desktop/features/users/domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.username,
    required super.email,
    required super.firstName,
    required super.lastName,
    required super.isActive,
    required super.createdAt,
    required super.roleNames,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      roleNames: (json['roles'] as List<dynamic>? ?? const [])
          .map(
            (role) => (role as Map<String, dynamic>)['name'] as String? ?? '',
          )
          .where((name) => name.isNotEmpty)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'isActive': isActive,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}
