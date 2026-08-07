import 'package:padelclub_desktop/features/tournament/domain/entities/tournament.dart';

abstract class TournamentRepository {
  Future<List<Tournament>> getTournaments({Map<String, dynamic>? filter});
}
