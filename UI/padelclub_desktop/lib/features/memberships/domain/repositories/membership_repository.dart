import 'package:padelclub_desktop/features/memberships/domain/entities/membership_event.dart';
import 'package:padelclub_desktop/features/memberships/domain/entities/membership_page.dart';

abstract class MembershipRepository {
  Future<MembershipPage> getMyMemberships({Map<String, dynamic>? filter});

  Future<void> cancelAtPeriodEnd(int membershipId);

  Future<void> setAutoRenew(int membershipId, bool enabled);

  Future<List<MembershipEvent>> getHistory(int membershipId);
}
