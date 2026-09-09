import 'package:padelclub_desktop/features/memberships/domain/entities/membership_page.dart';
import 'package:padelclub_desktop/features/memberships/domain/repositories/membership_repository.dart';

class GetMemberships {
  final MembershipRepository repository;

  const GetMemberships(this.repository);

  Future<MembershipPage> call({Map<String, dynamic>? filter}) =>
      repository.getMyMemberships(filter: filter);
}
