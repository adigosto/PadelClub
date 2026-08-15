import 'package:padelclub_desktop/features/tournament_participants/domain/entities/tournament_participant.dart';

abstract class TournamentParticipantRepository {
  Future<List<TournamentParticipant>> getTournamentParticipants({
    Map<String, dynamic>? filter,
  });
}
