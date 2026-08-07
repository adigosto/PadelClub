import 'package:padelclub_desktop/features/roles/data/datasources/role_remote_data_source.dart';
import 'package:padelclub_desktop/features/roles/domain/entities/role.dart';
import 'package:padelclub_desktop/features/roles/domain/repositories/role_repository.dart';

class RoleRepositoryImpl implements RoleRepository {
  final RoleRemoteDataSource remoteDataSource;

  RoleRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<Role>> getRoles({Map<String, dynamic>? filter}) async {
    return await remoteDataSource.getRoles(filter: filter);
  }
}
