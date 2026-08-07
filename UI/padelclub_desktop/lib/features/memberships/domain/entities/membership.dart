class Membership {
  final int? id;
  final int userId;
  final String membershipType;
  final DateTime startDate;
  final DateTime endDate;
  final double price;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Membership({
    this.id,
    required this.userId,
    required this.membershipType,
    required this.startDate,
    required this.endDate,
    required this.price,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });
}
