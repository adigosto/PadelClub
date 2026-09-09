import 'package:padelclub_desktop/features/memberships/domain/entities/membership.dart';

/// Mirrors the API's paged membership response envelope.
class MembershipPage {
  const MembershipPage({required this.items, this.totalCount});

  final List<Membership> items;
  final int? totalCount;
}
