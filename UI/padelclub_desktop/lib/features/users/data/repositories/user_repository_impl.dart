import 'package:padelclub_desktop/features/users/data/datasources/user_remote_data_source.dart';
import 'package:padelclub_desktop/features/users/domain/entities/user.dart';
import 'package:padelclub_desktop/features/users/domain/repositories/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource remoteDataSource;

  UserRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<User>> getUsers({Map<String, dynamic>? filter}) async {
    return await remoteDataSource.getUsers(filter: filter);
  }
}
