import 'package:padelclub_desktop/features/users/domain/entities/user.dart';
import 'package:padelclub_desktop/features/users/domain/repositories/user_repository.dart';

class GetUsers {
  final UserRepository repository;

  const GetUsers(this.repository);

  Future<List<User>> call({Map<String, dynamic>? filter}) {
    return repository.getUsers(filter: filter);
  }
}
