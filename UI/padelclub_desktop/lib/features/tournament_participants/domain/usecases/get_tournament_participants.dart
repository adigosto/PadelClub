import 'package:padelclub_desktop/features/tournament_participants/domain/entities/tournament_participant.dart';
import 'package:padelclub_desktop/features/tournament_participants/domain/repositories/tournament_participant_repository.dart';

class GetTournamentParticipants {
  final TournamentParticipantRepository repository;

  const GetTournamentParticipants(this.repository);

  Future<List<TournamentParticipant>> call({Map<String, dynamic>? filter}) {
    return repository.getTournamentParticipants(filter: filter);
  }
}
