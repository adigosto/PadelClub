import 'package:padelclub_desktop/features/roles/domain/entities/role.dart';

abstract class RoleRepository {
  Future<List<Role>> getRoles({Map<String, dynamic>? filter});
}
