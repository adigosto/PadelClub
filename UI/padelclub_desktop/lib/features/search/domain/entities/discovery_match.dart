class DiscoveryMatch {
  const DiscoveryMatch({
    required this.id,
    required this.tournamentName,
    required this.courtName,
    required this.scheduledTime,
    required this.status,
    required this.teamOne,
    required this.teamTwo,
    this.score,
  });

  final int id;
  final String tournamentName;
  final String courtName;
  final DateTime scheduledTime;
  final String status;
  final String? score;
  final List<String> teamOne;
  final List<String> teamTwo;
}
