class AccountCredit {
  const AccountCredit({
    required this.id,
    required this.amount,
    required this.reason,
    required this.createdAt,
    this.reservationId,
    this.usedAt,
  });

  final int id;
  final int? reservationId;
  final double amount;
  final String reason;
  final DateTime createdAt;
  final DateTime? usedAt;

  bool get isAvailable => usedAt == null;
}
