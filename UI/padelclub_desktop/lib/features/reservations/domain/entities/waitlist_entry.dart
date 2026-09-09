class WaitlistEntry {
  const WaitlistEntry({
    this.courtName = '',
    required this.id,
    required this.courtId,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.createdAt,
  });

  final String courtName;
  final int id;
  final int courtId;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final DateTime createdAt;
}
