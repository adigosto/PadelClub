import 'package:padelclub_desktop/features/memberships/domain/entities/membership_event.dart';

class MembershipEventModel extends MembershipEvent {
  const MembershipEventModel({
    required super.id,
    required super.eventType,
    required super.notes,
    required super.actorUserId,
    required super.createdAt,
  });

  factory MembershipEventModel.fromJson(Map<String, dynamic> json) =>
      MembershipEventModel(
        id: json['id'] as int? ?? 0,
        eventType: json['eventType'] as String? ?? 'Membership activity',
        notes: json['notes'] as String?,
        actorUserId: json['actorUserId'] as int?,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}
