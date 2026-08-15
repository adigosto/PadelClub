import 'package:padelclub_desktop/features/match_participants/domain/entities/match_participant.dart';

class MatchParticipantModel extends MatchParticipant {
  MatchParticipantModel({
    super.id,
    required super.matchId,
    required super.userId,
    required super.teamNumber,
    required super.role,
    required super.createdAt,
  });

  factory MatchParticipantModel.fromJson(Map<String, dynamic> json) {
    return MatchParticipantModel(
      id: json['id'] as int?,
      matchId: json['matchId'] as int,
      userId: json['userId'] as int,
      teamNumber: (json['teamNumber'] as num).toInt(),
      role: json['role'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'matchId': matchId,
    'userId': userId,
    'teamNumber': teamNumber,
    'role': role,
    'createdAt': createdAt.toIso8601String(),
  };
}
