class Membership {
  final int? id;
  final int userId;
  final int? membershipTypeReferenceId;
  final String membershipType;
  final DateTime startDate;
  final DateTime endDate;
  final double price;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String status;
  final bool autoRenew;
  final bool cancelAtPeriodEnd;
  final DateTime? suspendedAt;
  final DateTime? cancelledAt;

  Membership({
    this.id,
    required this.userId,
    this.membershipTypeReferenceId,
    required this.membershipType,
    required this.startDate,
    required this.endDate,
    required this.price,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    required this.status,
    required this.autoRenew,
    required this.cancelAtPeriodEnd,
    this.suspendedAt,
    this.cancelledAt,
  });

  /// These are only presentation affordances. The API remains the authority
  /// for whether a lifecycle change is allowed for a given membership.
  bool get canScheduleCancellation =>
      (status == 'Active' || status == 'Suspended') && !cancelAtPeriodEnd;

  bool get canChangeAutoRenew => status == 'Active';

  Membership copyWith({
    String? status,
    bool? autoRenew,
    bool? cancelAtPeriodEnd,
    DateTime? suspendedAt,
    DateTime? cancelledAt,
  }) => Membership(
    id: id,
    userId: userId,
    membershipTypeReferenceId: membershipTypeReferenceId,
    membershipType: membershipType,
    startDate: startDate,
    endDate: endDate,
    price: price,
    isActive: isActive,
    createdAt: createdAt,
    updatedAt: updatedAt,
    status: status ?? this.status,
    autoRenew: autoRenew ?? this.autoRenew,
    cancelAtPeriodEnd: cancelAtPeriodEnd ?? this.cancelAtPeriodEnd,
    suspendedAt: suspendedAt ?? this.suspendedAt,
    cancelledAt: cancelledAt ?? this.cancelledAt,
  );
}
