class MembershipEvent {
  const MembershipEvent({
    required this.id,
    required this.eventType,
    required this.notes,
    required this.actorUserId,
    required this.createdAt,
  });

  final int id;
  final String eventType;
  final String? notes;
  final int? actorUserId;
  final DateTime createdAt;
}
