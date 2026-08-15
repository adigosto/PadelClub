import 'package:padelclub_desktop/features/search/domain/entities/discovery_match.dart';
import 'package:padelclub_desktop/features/search/domain/entities/player_ranking.dart';

class DiscoveryMatchModel extends DiscoveryMatch {
  const DiscoveryMatchModel({
    required super.id,
    required super.tournamentName,
    required super.courtName,
    required super.scheduledTime,
    required super.status,
    required super.teamOne,
    required super.teamTwo,
    super.score,
  });

  factory DiscoveryMatchModel.fromJson(Map<String, dynamic> json) =>
      DiscoveryMatchModel(
        id: json['id'] as int,
        tournamentName: json['tournamentName'] as String? ?? '',
        courtName: json['courtName'] as String? ?? '',
        scheduledTime: DateTime.parse(json['scheduledTime'] as String),
        status: json['status'] as String? ?? '',
        score: json['score'] as String?,
        teamOne: (json['teamOne'] as List<dynamic>? ?? const []).cast<String>(),
        teamTwo: (json['teamTwo'] as List<dynamic>? ?? const []).cast<String>(),
      );
}

class PlayerRankingModel extends PlayerRanking {
  const PlayerRankingModel({
    required super.userId,
    required super.playerName,
    required super.matchesPlayed,
    required super.wins,
    super.rating,
    super.winRate,
  });

  factory PlayerRankingModel.fromJson(Map<String, dynamic> json) =>
      PlayerRankingModel(
        userId: json['userId'] as int,
        playerName: json['playerName'] as String? ?? '',
        matchesPlayed: json['matchesPlayed'] as int? ?? 0,
        wins: json['wins'] as int? ?? 0,
        rating: json['rating'] as int? ?? 1000,
        winRate: (json['winRate'] as num?)?.toDouble() ?? 0,
      );
}
