import 'package:padelclub_desktop/features/roles/domain/entities/role.dart';
import 'package:padelclub_desktop/features/roles/domain/repositories/role_repository.dart';

class GetRoles {
  final RoleRepository repository;

  const GetRoles(this.repository);

  Future<List<Role>> call({Map<String, dynamic>? filter}) {
    return repository.getRoles(filter: filter);
  }
}
