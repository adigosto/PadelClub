import 'package:padelclub_desktop/features/memberships/domain/entities/membership.dart';

abstract class MembershipRepository {
  Future<List<Membership>> getMemberships({Map<String, dynamic>? filter});
}
