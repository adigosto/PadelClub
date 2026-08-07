class MatchParticipant {
  final int? id;
  final int matchId;
  final int userId;
  final int teamNumber;
  final String role;
  final DateTime createdAt;

  MatchParticipant({
    this.id,
    required this.matchId,
    required this.userId,
    required this.teamNumber,
    required this.role,
    required this.createdAt,
  });
}
