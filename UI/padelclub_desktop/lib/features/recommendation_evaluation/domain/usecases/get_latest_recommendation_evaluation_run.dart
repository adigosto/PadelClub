import 'package:padelclub_desktop/features/recommendation_evaluation/domain/entities/recommendation_evaluation.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/domain/repositories/recommendation_evaluation_repository.dart';

class GetLatestRecommendationEvaluationRun {
  const GetLatestRecommendationEvaluationRun(this._repository);

  final RecommendationEvaluationRepository _repository;

  Future<RecommendationEvaluationRun?> call() {
    return _repository.getLatestEvaluationRun();
  }
}
