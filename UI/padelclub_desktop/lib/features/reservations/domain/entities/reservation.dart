class Reservation {
  const Reservation({
    required this.id,
    required this.courtId,
    required this.userId,
    required this.startTime,
    required this.endTime,
    required this.totalPrice,
    required this.status,
    this.notes,
    this.courtName = '',
    this.userName = '',
  });

  final int id;
  final String courtName;
  final String userName;
  final int courtId;
  final int userId;
  final DateTime startTime;
  final DateTime endTime;
  final double totalPrice;
  final String status;
  final String? notes;
}
