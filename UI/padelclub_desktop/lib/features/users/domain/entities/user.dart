class User {
  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.isActive,
    required this.createdAt,
    this.roleNames = const [],
  });

  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final bool isActive;
  final DateTime createdAt;
  final List<String> roleNames;

  String get displayName {
    final fullName = '$firstName $lastName'.trim();
    return fullName.isEmpty ? username : fullName;
  }
}
