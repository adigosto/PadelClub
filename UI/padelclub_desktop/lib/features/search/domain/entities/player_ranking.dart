class PlayerRanking {
  const PlayerRanking({
    required this.userId,
    required this.playerName,
    required this.matchesPlayed,
    required this.wins,
    this.rating = 1000,
    this.winRate = 0,
  });

  final int userId;
  final String playerName;
  final int matchesPlayed;
  final int wins;
  final int rating;
  final double winRate;
}
