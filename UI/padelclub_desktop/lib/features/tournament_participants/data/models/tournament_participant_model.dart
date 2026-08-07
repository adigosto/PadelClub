import 'package:padelclub_desktop/features/tournament_participants/domain/entities/tournament_participant.dart';

class TournamentParticipantModel extends TournamentParticipant {
  TournamentParticipantModel({super.id, required super.tournamentId, required super.userId});

  factory TournamentParticipantModel.fromJson(Map<String, dynamic> json) {
    return TournamentParticipantModel(
      id: json['id'] as int?,
      tournamentId: json['tournamentId'] as int,
      userId: json['userId'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tournamentId': tournamentId,
        'userId': userId,
      };
}
