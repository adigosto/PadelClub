import 'package:padelclub_desktop/features/users/domain/entities/user.dart';

abstract class UserRepository {
  Future<List<User>> getUsers({Map<String, dynamic>? filter});
}
