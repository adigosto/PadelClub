import 'package:flutter/foundation.dart';

import 'package:padelclub_desktop/features/tournament/domain/entities/tournament.dart';
import 'package:padelclub_desktop/features/tournament_management/data/tournament_management_remote_data_source.dart';
import 'package:padelclub_desktop/features/tournament_management/domain/entities/tournament_draft.dart';

/// Keeps administrator CRUD and one-way bracket work isolated from the player
/// tournament provider.
class TournamentManagementProvider extends ChangeNotifier {
  TournamentManagementProvider(this._dataSource);

  factory TournamentManagementProvider.live() =>
      TournamentManagementProvider(TournamentManagementRemoteDataSourceImpl());

  final TournamentManagementRemoteDataSource _dataSource;

  List<Tournament> _tournaments = const [];
  String _lastQuery = '';
  bool _isLoading = false;
  bool _isSaving = false;
  int? _processingTournamentId;
  String? _errorMessage;
  String? _lastOperationMessage;

  List<Tournament> get tournaments => List.unmodifiable(_tournaments);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  int? get processingTournamentId => _processingTournamentId;
  String? get errorMessage => _errorMessage;
  String? get lastOperationMessage => _lastOperationMessage;

  bool isProcessing(int tournamentId) =>
      _processingTournamentId == tournamentId;

  Future<void> load({String? query}) async {
    if (_isLoading || _isSaving) return;
    _lastQuery = query?.trim() ?? '';
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _tournaments = List.unmodifiable(
        await _dataSource.getTournaments(query: _lastQuery),
      );
    } catch (error) {
      _errorMessage = _message(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> create(TournamentDraft draft) => _operate(
    action: () => _dataSource.createTournament(draft),
    successLabel: 'Tournament created',
  );

  Future<bool> update({
    required int tournamentId,
    required TournamentDraft draft,
  }) => _operate(
    tournamentId: tournamentId,
    action: () =>
        _dataSource.updateTournament(tournamentId: tournamentId, draft: draft),
    successLabel: 'Tournament updated',
  );

  Future<bool> delete(int tournamentId) => _operate(
    tournamentId: tournamentId,
    action: () => _dataSource.deleteTournament(tournamentId),
    successLabel: 'Tournament permanently deleted',
  );

  Future<bool> generateBracket(int tournamentId) => _operate(
    tournamentId: tournamentId,
    action: () => _dataSource.generateBracket(tournamentId),
    successLabel: 'Bracket generated',
  );

  Future<bool> _operate({
    int? tournamentId,
    required Future<void> Function() action,
    required String successLabel,
  }) async {
    if (_isLoading || _isSaving) return false;
    _isSaving = true;
    _processingTournamentId = tournamentId;
    _errorMessage = null;
    _lastOperationMessage = null;
    notifyListeners();
    try {
      await action();
      try {
        _tournaments = List.unmodifiable(
          await _dataSource.getTournaments(query: _lastQuery),
        );
        _lastOperationMessage = '$successLabel and refreshed from the server.';
      } catch (error) {
        _lastOperationMessage =
            '$successLabel, but the latest list could not be refreshed: ${_message(error)}';
      }
      return true;
    } catch (error) {
      _errorMessage = _message(error);
      return false;
    } finally {
      _processingTournamentId = null;
      _isSaving = false;
      notifyListeners();
    }
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Bad state: ', '');
}
