import 'package:padelclub_desktop/features/memberships/domain/entities/membership.dart';

class MembershipModel extends Membership {
  MembershipModel({
    super.id,
    required super.userId,
    super.membershipTypeReferenceId,
    required super.membershipType,
    required super.startDate,
    required super.endDate,
    required super.price,
    required super.isActive,
    required super.createdAt,
    super.updatedAt,
    required super.status,
    required super.autoRenew,
    required super.cancelAtPeriodEnd,
    super.suspendedAt,
    super.cancelledAt,
  });

  factory MembershipModel.fromJson(Map<String, dynamic> json) {
    return MembershipModel(
      id: json['id'] as int?,
      userId: json['userId'] as int? ?? 0,
      membershipTypeReferenceId: json['membershipTypeReferenceId'] as int?,
      membershipType: json['membershipType'] as String? ?? 'Membership',
      startDate: _date(json['startDate']),
      endDate: _date(json['endDate']),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      isActive: json['isActive'] as bool? ?? false,
      createdAt: _date(json['createdAt']),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      status: json['status'] as String? ?? 'Unknown',
      autoRenew: json['autoRenew'] as bool? ?? false,
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] as bool? ?? false,
      suspendedAt: json['suspendedAt'] == null
          ? null
          : DateTime.parse(json['suspendedAt'] as String),
      cancelledAt: json['cancelledAt'] == null
          ? null
          : DateTime.parse(json['cancelledAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'membershipTypeReferenceId': membershipTypeReferenceId,
    'membershipType': membershipType,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'price': price,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'status': status,
    'autoRenew': autoRenew,
    'cancelAtPeriodEnd': cancelAtPeriodEnd,
    'suspendedAt': suspendedAt?.toIso8601String(),
    'cancelledAt': cancelledAt?.toIso8601String(),
  };

  static DateTime _date(Object? value) =>
      DateTime.tryParse(value as String? ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
