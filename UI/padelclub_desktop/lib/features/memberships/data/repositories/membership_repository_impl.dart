import 'package:padelclub_desktop/features/memberships/data/datasources/membership_remote_data_source.dart';
import 'package:padelclub_desktop/features/memberships/domain/entities/membership_event.dart';
import 'package:padelclub_desktop/features/memberships/domain/entities/membership_page.dart';
import 'package:padelclub_desktop/features/memberships/domain/repositories/membership_repository.dart';

class MembershipRepositoryImpl implements MembershipRepository {
  final MembershipRemoteDataSource remoteDataSource;

  MembershipRepositoryImpl({required this.remoteDataSource});

  @override
  Future<MembershipPage> getMyMemberships({Map<String, dynamic>? filter}) =>
      remoteDataSource.getMine(filter: filter);

  @override
  Future<void> cancelAtPeriodEnd(int membershipId) =>
      remoteDataSource.cancelAtPeriodEnd(membershipId);

  @override
  Future<void> setAutoRenew(int membershipId, bool enabled) =>
      remoteDataSource.setAutoRenew(membershipId, enabled);

  @override
  Future<List<MembershipEvent>> getHistory(int membershipId) =>
      remoteDataSource.getHistory(membershipId);
}
