import 'package:padelclub_desktop/features/recommendation_evaluation/domain/entities/recommendation_evaluation.dart';

abstract interface class RecommendationEvaluationRepository {
  Future<RecommendationEvaluation> getEvaluation({
    required DateTime cutoffUtc,
    required DateTime endUtc,
    required int k,
  });

  Future<RecommendationEvaluationRun> createEvaluationRun({
    required DateTime cutoffUtc,
    required DateTime endUtc,
    required int k,
  });

  Future<RecommendationEvaluationRun?> getLatestEvaluationRun();
}
