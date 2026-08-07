import 'package:padelclub_desktop/features/tournament/domain/entities/tournament.dart';
import 'package:padelclub_desktop/features/tournament/domain/repositories/tournament_repository.dart';

class GetTournaments {
  final TournamentRepository repository;

  const GetTournaments(this.repository);

  Future<List<Tournament>> call({Map<String, dynamic>? filter}) {
    return repository.getTournaments(filter: filter);
  }
}
