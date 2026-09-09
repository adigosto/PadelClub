import 'package:padelclub_desktop/features/recommendation_evaluation/data/datasources/recommendation_evaluation_remote_data_source.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/domain/entities/recommendation_evaluation.dart';
import 'package:padelclub_desktop/features/recommendation_evaluation/domain/repositories/recommendation_evaluation_repository.dart';

class RecommendationEvaluationRepositoryImpl
    implements RecommendationEvaluationRepository {
  const RecommendationEvaluationRepositoryImpl(this._remoteDataSource);

  final RecommendationEvaluationRemoteDataSource _remoteDataSource;

  @override
  Future<RecommendationEvaluation> getEvaluation({
    required DateTime cutoffUtc,
    required DateTime endUtc,
    required int k,
  }) {
    return _remoteDataSource.getEvaluation(
      cutoffUtc: cutoffUtc,
      endUtc: endUtc,
      k: k,
    );
  }

  @override
  Future<RecommendationEvaluationRun> createEvaluationRun({
    required DateTime cutoffUtc,
    required DateTime endUtc,
    required int k,
  }) {
    return _remoteDataSource.createEvaluationRun(
      cutoffUtc: cutoffUtc,
      endUtc: endUtc,
      k: k,
    );
  }

  @override
  Future<RecommendationEvaluationRun?> getLatestEvaluationRun() {
    return _remoteDataSource.getLatestEvaluationRun();
  }
}
