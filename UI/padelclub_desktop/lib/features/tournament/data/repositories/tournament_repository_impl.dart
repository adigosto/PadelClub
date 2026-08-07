import 'package:padelclub_desktop/features/tournament/data/datasources/tournament_remote_data_source.dart';
import 'package:padelclub_desktop/features/tournament/domain/entities/tournament.dart';
import 'package:padelclub_desktop/features/tournament/domain/repositories/tournament_repository.dart';

class TournamentRepositoryImpl implements TournamentRepository {
  final TournamentRemoteDataSource remoteDataSource;

  TournamentRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<Tournament>> getTournaments({Map<String, dynamic>? filter}) async {
    return await remoteDataSource.getTournaments(filter: filter);
  }
}
