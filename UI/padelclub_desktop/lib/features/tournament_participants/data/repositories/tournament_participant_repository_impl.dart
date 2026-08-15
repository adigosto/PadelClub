import 'package:padelclub_desktop/features/tournament_participants/data/datasources/tournament_participant_remote_data_source.dart';
import 'package:padelclub_desktop/features/tournament_participants/domain/entities/tournament_participant.dart';
import 'package:padelclub_desktop/features/tournament_participants/domain/repositories/tournament_participant_repository.dart';

class TournamentParticipantRepositoryImpl
    implements TournamentParticipantRepository {
  final TournamentParticipantRemoteDataSource remoteDataSource;

  TournamentParticipantRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<TournamentParticipant>> getTournamentParticipants({
    Map<String, dynamic>? filter,
  }) async {
    return await remoteDataSource.getTournamentParticipants(filter: filter);
  }
}
