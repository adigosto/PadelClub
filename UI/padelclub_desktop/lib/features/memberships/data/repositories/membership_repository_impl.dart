import 'package:padelclub_desktop/features/memberships/data/datasources/membership_remote_data_source.dart';
import 'package:padelclub_desktop/features/memberships/domain/entities/membership.dart';
import 'package:padelclub_desktop/features/memberships/domain/repositories/membership_repository.dart';

class MembershipRepositoryImpl implements MembershipRepository {
  final MembershipRemoteDataSource remoteDataSource;

  MembershipRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<Membership>> getMemberships({Map<String, dynamic>? filter}) async {
    return await remoteDataSource.getMemberships(filter: filter);
  }
}
