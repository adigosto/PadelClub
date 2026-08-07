import 'package:padelclub_desktop/features/match_participants/domain/entities/match_participant.dart';
import 'package:padelclub_desktop/features/match_participants/domain/repositories/match_participant_repository.dart';

class GetMatchParticipants {
  final MatchParticipantRepository repository;

  const GetMatchParticipants(this.repository);

  Future<List<MatchParticipant>> call({Map<String, dynamic>? filter}) {
    return repository.getMatchParticipants(filter: filter);
  }
}
