import 'package:padelclub_desktop/features/match_participants/data/datasources/match_participant_remote_data_source.dart';
import 'package:padelclub_desktop/features/match_participants/domain/entities/match_participant.dart';
import 'package:padelclub_desktop/features/match_participants/domain/repositories/match_participant_repository.dart';

class MatchParticipantRepositoryImpl implements MatchParticipantRepository {
  final MatchParticipantRemoteDataSource remoteDataSource;

  MatchParticipantRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<MatchParticipant>> getMatchParticipants({Map<String, dynamic>? filter}) async {
    return await remoteDataSource.getMatchParticipants(filter: filter);
  }
}
