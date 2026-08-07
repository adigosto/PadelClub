import 'package:padelclub_desktop/features/memberships/domain/entities/membership.dart';
import 'package:padelclub_desktop/features/memberships/domain/repositories/membership_repository.dart';

class GetMemberships {
  final MembershipRepository repository;

  const GetMemberships(this.repository);

  Future<List<Membership>> call({Map<String, dynamic>? filter}) {
    return repository.getMemberships(filter: filter);
  }
}
