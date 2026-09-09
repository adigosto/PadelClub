import 'package:flutter/foundation.dart';

import 'package:padelclub_desktop/features/recommendation_evaluation/domain/entities/recommendation_evaluation.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/domain/usecases/create_recommendation_evaluation_run.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/domain/usecases/get_recommendation_evaluation.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/domain/usecases/get_latest_recommendation_evaluation_run.dart';

class RecommendationEvaluationProvider extends ChangeNotifier {
  RecommendationEvaluationProvider(
    this._getRecommendationEvaluation,
    this._createRecommendationEvaluationRun,
    this._getLatestRecommendationEvaluationRun,
  );

  final GetRecommendationEvaluation _getRecommendationEvaluation;
  final CreateRecommendationEvaluationRun _createRecommendationEvaluationRun;
  final GetLatestRecommendationEvaluationRun
  _getLatestRecommendationEvaluationRun;

  RecommendationEvaluation? _evaluation;
  RecommendationEvaluationRun? _latestRun;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  RecommendationEvaluation? get evaluation => _evaluation;
  RecommendationEvaluationRun? get latestRun => _latestRun;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  Future<void> load({
    required DateTime cutoffUtc,
    required DateTime endUtc,
    required int k,
  }) async {
    if (_isLoading) return;

    // A new request must not leave prior evidence beside a new set of controls,
    // including when the new request is rejected before the network call.
    _evaluation = null;
    _errorMessage = null;
    final cutoff = cutoffUtc.toUtc();
    final end = endUtc.toUtc();
    if (end.compareTo(cutoff) <= 0) {
      _errorMessage = 'The evaluation end must be after its cutoff.';
      notifyListeners();
      return;
    }
    if (end.difference(cutoff) > const Duration(days: 366)) {
      _errorMessage = 'Choose an evaluation window of at most 366 days.';
      notifyListeners();
      return;
    }
    if (k < 1 || k > 12) {
      _errorMessage = 'Choose K between 1 and 12.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _evaluation = await _getRecommendationEvaluation(
        cutoffUtc: cutoff,
        endUtc: end,
        k: k,
      );
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Bad state: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLatestRun() async {
    try {
      _latestRun = await _getLatestRecommendationEvaluationRun();
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Bad state: ', '');
    } finally {
      notifyListeners();
    }
  }

  Future<void> saveRun({
    required DateTime cutoffUtc,
    required DateTime endUtc,
    required int k,
  }) async {
    if (_isLoading || _isSaving) return;
    final cutoff = cutoffUtc.toUtc();
    final end = endUtc.toUtc();
    if (!_isValidRequest(cutoff: cutoff, end: end, k: k)) return;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final run = await _createRecommendationEvaluationRun(
        cutoffUtc: cutoff,
        endUtc: end,
        k: k,
      );
      _latestRun = run;
      _evaluation = run.report;
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Bad state: ', '');
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  bool _isValidRequest({
    required DateTime cutoff,
    required DateTime end,
    required int k,
  }) {
    if (end.compareTo(cutoff) <= 0) {
      _errorMessage = 'The evaluation end must be after its cutoff.';
      notifyListeners();
      return false;
    }
    if (end.difference(cutoff) > const Duration(days: 366)) {
      _errorMessage = 'Choose an evaluation window of at most 366 days.';
      notifyListeners();
      return false;
    }
    if (k < 1 || k > 12) {
      _errorMessage = 'Choose K between 1 and 12.';
      notifyListeners();
      return false;
    }
    return true;
  }
}
