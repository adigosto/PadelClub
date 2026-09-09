import 'package:padelclub_desktop/features/recommendation_evaluation/domain/entities/recommendation_evaluation.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/domain/repositories/recommendation_evaluation_repository.dart';

class GetRecommendationEvaluation {
  const GetRecommendationEvaluation(this._repository);

  final RecommendationEvaluationRepository _repository;

  Future<RecommendationEvaluation> call({
    required DateTime cutoffUtc,
    required DateTime endUtc,
    required int k,
  }) {
    return _repository.getEvaluation(
      cutoffUtc: cutoffUtc,
      endUtc: endUtc,
      k: k,
    );
  }
}
