class Tournament {
  const Tournament({
    this.id,
    required this.name,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.registrationDeadline,
    required this.maxParticipants,
    required this.entryFee,
    required this.status,
    this.prizeInfo,
  });

  final int? id;
  final String name;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime registrationDeadline;
  final int maxParticipants;
  final double entryFee;
  final String status;
  final String? prizeInfo;
}
