import 'package:padelclub_desktop/features/match_participants/domain/entities/match_participant.dart';

abstract class MatchParticipantRepository {
  Future<List<MatchParticipant>> getMatchParticipants({Map<String, dynamic>? filter});
}
