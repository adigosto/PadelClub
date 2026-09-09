import 'package:padelclub_desktop/features/recommendation_evaluation/domain/entities/recommendation_evaluation.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/domain/repositories/recommendation_evaluation_repository.dart';

class CreateRecommendationEvaluationRun {
  const CreateRecommendationEvaluationRun(this._repository);

  final RecommendationEvaluationRepository _repository;

  Future<RecommendationEvaluationRun> call({
    required DateTime cutoffUtc,
    required DateTime endUtc,
    required int k,
  }) {
    return _repository.createEvaluationRun(
      cutoffUtc: cutoffUtc,
      endUtc: endUtc,
      k: k,
    );
  }
}
