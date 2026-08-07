import 'package:padelclub_desktop/features/memberships/domain/entities/membership.dart';

class MembershipModel extends Membership {
  MembershipModel({
    super.id,
    required super.userId,
    required super.membershipType,
    required super.startDate,
    required super.endDate,
    required super.price,
    required super.isActive,
    required super.createdAt,
    super.updatedAt,
  });

  factory MembershipModel.fromJson(Map<String, dynamic> json) {
    return MembershipModel(
      id: json['id'] as int?,
      userId: json['userId'] as int,
      membershipType: json['membershipType'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      price: (json['price'] as num).toDouble(),
      isActive: json['isActive'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null ? null : DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'membershipType': membershipType,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'price': price,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };
}
