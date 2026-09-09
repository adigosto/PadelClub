import 'package:padelclub_desktop/features/recommendation_evaluation/domain/entities/recommendation_evaluation.dart';

/// Strict JSON representation of the recommendation-evaluation API contract.
///
/// Evaluation evidence must never turn a malformed response into a plausible
/// "no data" result. Required values are therefore parsed explicitly and the
/// availability/metric relationship is checked before the presentation layer
/// can render it.
class RecommendationEvaluationModel extends RecommendationEvaluation {
  const RecommendationEvaluationModel({
    required super.evidenceSource,
    required super.evidenceTier,
    required super.inputFingerprintSha256,
    required super.configurationSha256,
    required super.isAvailable,
    required super.isSmallSample,
    required super.protocol,
    required super.algorithmVersion,
    required super.cutoffUtc,
    required super.endUtc,
    required super.k,
    required super.cohort,
    required super.quality,
    required super.collaborativeFiltering,
    required super.popularityBaseline,
    required super.limitations,
    super.unavailableReason,
  });

  factory RecommendationEvaluationModel.fromJson(Map<String, dynamic> json) {
    final isAvailable = _requiredBool(json, 'isAvailable');
    final cohort = RecommendationEvaluationCohortModel.fromJson(
      _requiredObject(json, 'cohort'),
    );
    final quality = RecommendationEvaluationQualityModel.fromJson(
      _requiredObject(json, 'quality'),
    );
    final collaborativeFiltering =
        RecommendationEvaluationMethodMetricsModel.fromJson(
          _requiredObject(json, 'collaborativeFiltering'),
        );
    final popularityBaseline =
        RecommendationEvaluationMethodMetricsModel.fromJson(
          _requiredObject(json, 'popularityBaseline'),
        );
    final evaluation = RecommendationEvaluationModel(
      isAvailable: isAvailable,
      isSmallSample: _requiredBool(json, 'isSmallSample'),
      evidenceSource: _requiredNonBlankString(json, 'evidenceSource'),
      evidenceTier: _requiredEvidenceTier(json, 'evidenceTier'),
      inputFingerprintSha256: _requiredSha256(json, 'inputFingerprintSha256'),
      configurationSha256: _requiredSha256(json, 'configurationSha256'),
      unavailableReason: _optionalNonBlankString(json, 'unavailableReason'),
      protocol: _requiredNonBlankString(json, 'protocol'),
      algorithmVersion: _requiredNonBlankString(json, 'algorithmVersion'),
      cutoffUtc: _requiredUtcDateTime(json, 'cutoffUtc'),
      endUtc: _requiredUtcDateTime(json, 'endUtc'),
      k: _requiredInt(json, 'k'),
      cohort: cohort,
      quality: quality,
      collaborativeFiltering: collaborativeFiltering,
      popularityBaseline: popularityBaseline,
      limitations: _requiredStringList(json, 'limitations'),
    );

    _validateEvaluation(evaluation);
    return evaluation;
  }
}

class RecommendationEvaluationQualityModel
    extends RecommendationEvaluationQuality {
  const RecommendationEvaluationQualityModel({
    required super.policyVersion,
    required super.isMeaningful,
    required super.evidenceTier,
    required super.minimumHistoricalWindowDays,
    required super.minimumReturnMaturityDays,
    required super.minimumDeliveredOrders,
    required super.minimumTrainingSignals,
    required super.minimumHoldoutSignals,
    required super.minimumCandidateProducts,
    required super.minimumEvaluatedUsers,
    required super.unmetRequirements,
    required super.gates,
  });

  factory RecommendationEvaluationQualityModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final quality = RecommendationEvaluationQualityModel(
      policyVersion: _requiredNonBlankString(json, 'policyVersion'),
      isMeaningful: _requiredBool(json, 'isMeaningful'),
      evidenceTier: _requiredEvidenceTier(json, 'evidenceTier'),
      minimumHistoricalWindowDays: _requiredPositiveInt(
        json,
        'minimumHistoricalWindowDays',
      ),
      minimumReturnMaturityDays: _requiredPositiveInt(
        json,
        'minimumReturnMaturityDays',
      ),
      minimumDeliveredOrders: _requiredPositiveInt(
        json,
        'minimumDeliveredOrders',
      ),
      minimumTrainingSignals: _requiredPositiveInt(
        json,
        'minimumTrainingSignals',
      ),
      minimumHoldoutSignals: _requiredPositiveInt(
        json,
        'minimumHoldoutSignals',
      ),
      minimumCandidateProducts: _requiredPositiveInt(
        json,
        'minimumCandidateProducts',
      ),
      minimumEvaluatedUsers: _requiredPositiveInt(
        json,
        'minimumEvaluatedUsers',
      ),
      unmetRequirements: _requiredStringList(json, 'unmetRequirements'),
      gates: _requiredList(json, 'gates')
          .map(
            (value) => RecommendationEvaluationQualityGateModel.fromJson(
              _asRequiredObject(value, 'gates'),
            ),
          )
          .toList(growable: false),
    );
    if (quality.isMeaningful == quality.unmetRequirements.isNotEmpty) {
      throw const FormatException(
        'Recommendation evaluation quality requirements are contradictory.',
      );
    }
    final expectedTier = quality.isMeaningful ? 'Qualified' : 'Diagnostic';
    if (quality.evidenceTier != expectedTier &&
        quality.evidenceTier != 'Unavailable') {
      throw const FormatException(
        'Recommendation evaluation quality evidence tier is invalid.',
      );
    }
    if (quality.gates.isEmpty) {
      throw const FormatException(
        'Recommendation evaluation quality gates are missing.',
      );
    }
    return quality;
  }
}

class RecommendationEvaluationCohortModel
    extends RecommendationEvaluationCohort {
  const RecommendationEvaluationCohortModel({
    required super.deliveredOrders,
    required super.excludedSeededDemoOrders,
    required super.excludedUnverifiedLegacyOrders,
    required super.excludedNonOperationalOrders,
    required super.excludedOrdersWithoutDeliveredAt,
    required super.unresolvedApprovedOrRefundedReturns,
    required super.distinctCustomers,
    required super.candidateProductsWithAtLeastTwoDistinctBuyers,
    required super.historicalObservationDays,
    required super.eligibleOrderOrigins,
    required super.trainingOrders,
    required super.holdoutOrders,
    required super.trainingSignals,
    required super.holdoutSignals,
    required super.candidateProducts,
    required super.evaluatedUsers,
    required super.coldStartUsers,
    required super.usersWithoutNovelHoldout,
    required super.excludedHoldoutProductsWithoutTrainingEvidence,
    required super.legacyDeliveryTimestampFallbacks,
  });

  factory RecommendationEvaluationCohortModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return RecommendationEvaluationCohortModel(
      deliveredOrders: _requiredNonNegativeInt(json, 'deliveredOrders'),
      excludedSeededDemoOrders: _requiredNonNegativeInt(
        json,
        'excludedSeededDemoOrders',
      ),
      excludedUnverifiedLegacyOrders: _requiredNonNegativeInt(
        json,
        'excludedUnverifiedLegacyOrders',
      ),
      excludedNonOperationalOrders: _requiredNonNegativeInt(
        json,
        'excludedNonOperationalOrders',
      ),
      excludedOrdersWithoutDeliveredAt: _requiredNonNegativeInt(
        json,
        'excludedOrdersWithoutDeliveredAt',
      ),
      unresolvedApprovedOrRefundedReturns: _requiredNonNegativeInt(
        json,
        'unresolvedApprovedOrRefundedReturns',
      ),
      distinctCustomers: _requiredNonNegativeInt(json, 'distinctCustomers'),
      candidateProductsWithAtLeastTwoDistinctBuyers: _requiredNonNegativeInt(
        json,
        'candidateProductsWithAtLeastTwoDistinctBuyers',
      ),
      historicalObservationDays: _requiredNonNegativeInt(
        json,
        'historicalObservationDays',
      ),
      eligibleOrderOrigins: _requiredStringList(json, 'eligibleOrderOrigins'),
      trainingOrders: _requiredNonNegativeInt(json, 'trainingOrders'),
      holdoutOrders: _requiredNonNegativeInt(json, 'holdoutOrders'),
      trainingSignals: _requiredNonNegativeInt(json, 'trainingSignals'),
      holdoutSignals: _requiredNonNegativeInt(json, 'holdoutSignals'),
      candidateProducts: _requiredNonNegativeInt(json, 'candidateProducts'),
      evaluatedUsers: _requiredNonNegativeInt(json, 'evaluatedUsers'),
      coldStartUsers: _requiredNonNegativeInt(json, 'coldStartUsers'),
      usersWithoutNovelHoldout: _requiredNonNegativeInt(
        json,
        'usersWithoutNovelHoldout',
      ),
      excludedHoldoutProductsWithoutTrainingEvidence: _requiredNonNegativeInt(
        json,
        'excludedHoldoutProductsWithoutTrainingEvidence',
      ),
      legacyDeliveryTimestampFallbacks: _requiredNonNegativeInt(
        json,
        'legacyDeliveryTimestampFallbacks',
      ),
    );
  }
}

class RecommendationEvaluationQualityGateModel
    extends RecommendationEvaluationQualityGate {
  const RecommendationEvaluationQualityGateModel({
    required super.name,
    required super.passed,
    required super.observed,
    required super.required,
    required super.detail,
  });

  factory RecommendationEvaluationQualityGateModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return RecommendationEvaluationQualityGateModel(
      name: _requiredNonBlankString(json, 'name'),
      passed: _requiredBool(json, 'passed'),
      observed: _requiredNonBlankString(json, 'observed'),
      required: _requiredNonBlankString(json, 'required'),
      detail: _requiredNonBlankString(json, 'detail'),
    );
  }
}

class RecommendationEvaluationRunModel extends RecommendationEvaluationRun {
  const RecommendationEvaluationRunModel({
    required super.runId,
    required super.executedByUserId,
    required super.executedAtUtc,
    required super.evidenceSource,
    required super.evidenceTier,
    required super.inputFingerprintSha256,
    required super.configurationSha256,
    required super.report,
  });

  factory RecommendationEvaluationRunModel.fromJson(Map<String, dynamic> json) {
    final report = RecommendationEvaluationModel.fromJson(
      _requiredObject(json, 'report'),
    );
    final model = RecommendationEvaluationRunModel(
      runId: _requiredGuid(json, 'runId'),
      executedByUserId: _requiredPositiveInt(json, 'executedByUserId'),
      executedAtUtc: _requiredUtcDateTime(json, 'executedAtUtc'),
      evidenceSource: _requiredNonBlankString(json, 'evidenceSource'),
      evidenceTier: _requiredEvidenceTier(json, 'evidenceTier'),
      inputFingerprintSha256: _requiredSha256(json, 'inputFingerprintSha256'),
      configurationSha256: _requiredSha256(json, 'configurationSha256'),
      report: report,
    );
    if (model.evidenceSource != report.evidenceSource ||
        model.evidenceTier != report.evidenceTier ||
        model.inputFingerprintSha256 != report.inputFingerprintSha256 ||
        model.configurationSha256 != report.configurationSha256) {
      throw const FormatException(
        'Persisted recommendation evaluation evidence does not match its report.',
      );
    }
    return model;
  }
}

class RecommendationEvaluationMethodMetricsModel
    extends RecommendationEvaluationMethodMetrics {
  const RecommendationEvaluationMethodMetricsModel({
    required super.method,
    required super.precisionAtK,
    required super.recallAtK,
    required super.hitRateAtK,
    required super.meanReciprocalRankAtK,
    required super.normalizedDiscountedCumulativeGainAtK,
    required super.catalogCoverageAtK,
    required super.averageRecommendationsReturned,
    required super.totalHits,
    required super.usersWithRecommendations,
  });

  factory RecommendationEvaluationMethodMetricsModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final metrics = RecommendationEvaluationMethodMetricsModel(
      method: _requiredNonBlankString(json, 'method'),
      precisionAtK: _nullableNonNegativeDouble(json, 'precisionAtK'),
      recallAtK: _nullableNonNegativeDouble(json, 'recallAtK'),
      hitRateAtK: _nullableNonNegativeDouble(json, 'hitRateAtK'),
      meanReciprocalRankAtK: _nullableNonNegativeDouble(
        json,
        'meanReciprocalRankAtK',
      ),
      normalizedDiscountedCumulativeGainAtK: _nullableNonNegativeDouble(
        json,
        'normalizedDiscountedCumulativeGainAtK',
      ),
      catalogCoverageAtK: _nullableNonNegativeDouble(
        json,
        'catalogCoverageAtK',
      ),
      averageRecommendationsReturned: _nullableNonNegativeDouble(
        json,
        'averageRecommendationsReturned',
      ),
      totalHits: _requiredNonNegativeInt(json, 'totalHits'),
      usersWithRecommendations: _requiredNonNegativeInt(
        json,
        'usersWithRecommendations',
      ),
    );
    _validateMethodMetricRanges(metrics);
    return metrics;
  }
}

void _validateEvaluation(RecommendationEvaluation evaluation) {
  if (evaluation.endUtc.compareTo(evaluation.cutoffUtc) <= 0) {
    throw const FormatException(
      'Recommendation evaluation endUtc must be after cutoffUtc.',
    );
  }
  if (evaluation.k < 1 || evaluation.k > 12) {
    throw const FormatException(
      'Recommendation evaluation k must be 1 through 12.',
    );
  }
  if (evaluation.quality.isMeaningful && !evaluation.isAvailable) {
    throw const FormatException(
      'An unavailable evaluation cannot satisfy the quality gates.',
    );
  }
  if (evaluation.evidenceSource != 'Operational' ||
      evaluation.evidenceTier != evaluation.quality.evidenceTier) {
    throw const FormatException(
      'Recommendation evaluation evidence source or tier is contradictory.',
    );
  }

  final methods = [
    evaluation.collaborativeFiltering,
    evaluation.popularityBaseline,
  ];
  if (evaluation.isAvailable) {
    if (evaluation.unavailableReason != null ||
        evaluation.cohort.evaluatedUsers == 0 ||
        methods.any((method) => !_hasCompleteMetrics(method))) {
      throw const FormatException(
        'An available recommendation evaluation is missing required metrics.',
      );
    }
    return;
  }

  if (evaluation.unavailableReason == null ||
      evaluation.cohort.evaluatedUsers != 0 ||
      methods.any(_hasUnavailableResultValues)) {
    throw const FormatException(
      'An unavailable recommendation evaluation contains contradictory evidence.',
    );
  }
}

bool _hasCompleteMetrics(RecommendationEvaluationMethodMetrics method) =>
    method.precisionAtK != null &&
    method.recallAtK != null &&
    method.hitRateAtK != null &&
    method.meanReciprocalRankAtK != null &&
    method.normalizedDiscountedCumulativeGainAtK != null &&
    method.catalogCoverageAtK != null &&
    method.averageRecommendationsReturned != null;

bool _hasUnavailableResultValues(
  RecommendationEvaluationMethodMetrics method,
) =>
    method.precisionAtK != null ||
    method.recallAtK != null ||
    method.hitRateAtK != null ||
    method.meanReciprocalRankAtK != null ||
    method.normalizedDiscountedCumulativeGainAtK != null ||
    method.catalogCoverageAtK != null ||
    method.averageRecommendationsReturned != null ||
    method.totalHits != 0 ||
    method.usersWithRecommendations != 0;

void _validateMethodMetricRanges(RecommendationEvaluationMethodMetrics method) {
  final unitIntervalMetrics = [
    method.precisionAtK,
    method.recallAtK,
    method.hitRateAtK,
    method.meanReciprocalRankAtK,
    method.normalizedDiscountedCumulativeGainAtK,
    method.catalogCoverageAtK,
  ];
  if (unitIntervalMetrics.any((value) => value != null && value > 1)) {
    throw const FormatException(
      'Recommendation evaluation metric values must be between zero and one.',
    );
  }
}

Map<String, dynamic> _requiredObject(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  throw FormatException(
    'Recommendation evaluation $key is missing or invalid.',
  );
}

Map<String, dynamic> _asRequiredObject(dynamic value, String key) {
  if (value is Map<String, dynamic>) return value;
  throw FormatException(
    'Recommendation evaluation $key contains an invalid object.',
  );
}

List<dynamic> _requiredList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List) return value;
  throw FormatException(
    'Recommendation evaluation $key is missing or invalid.',
  );
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException(
    'Recommendation evaluation $key is missing or invalid.',
  );
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException(
    'Recommendation evaluation $key is missing or invalid.',
  );
}

int _requiredNonNegativeInt(Map<String, dynamic> json, String key) {
  final value = _requiredInt(json, key);
  if (value >= 0) return value;
  throw FormatException('Recommendation evaluation $key cannot be negative.');
}

int _requiredPositiveInt(Map<String, dynamic> json, String key) {
  final value = _requiredInt(json, key);
  if (value > 0) return value;
  throw FormatException('Recommendation evaluation $key must be positive.');
}

double? _nullableNonNegativeDouble(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Recommendation evaluation $key is missing.');
  }
  final value = json[key];
  if (value == null) return null;
  if (value is num && value.isFinite && value >= 0) return value.toDouble();
  throw FormatException('Recommendation evaluation $key is invalid.');
}

String _requiredNonBlankString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException(
    'Recommendation evaluation $key is missing or invalid.',
  );
}

String _requiredEvidenceTier(Map<String, dynamic> json, String key) {
  final value = _requiredNonBlankString(json, key);
  if (value == 'Unavailable' || value == 'Diagnostic' || value == 'Qualified') {
    return value;
  }
  throw FormatException('Recommendation evaluation $key is invalid.');
}

String _requiredSha256(Map<String, dynamic> json, String key) {
  final value = _requiredNonBlankString(json, key);
  if (RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) return value;
  throw FormatException('Recommendation evaluation $key is invalid.');
}

String _requiredGuid(Map<String, dynamic> json, String key) {
  final value = _requiredNonBlankString(json, key);
  if (RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value)) {
    return value.toLowerCase();
  }
  throw FormatException('Recommendation evaluation $key is invalid.');
}

String? _optionalNonBlankString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('Recommendation evaluation $key is invalid.');
}

List<String> _requiredStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException(
      'Recommendation evaluation $key is missing or invalid.',
    );
  }
  if (value.any((item) => item is! String || item.trim().isEmpty)) {
    throw FormatException(
      'Recommendation evaluation $key contains an invalid item.',
    );
  }
  return value.cast<String>().toList(growable: false);
}

DateTime _requiredUtcDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('Recommendation evaluation $key is missing.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Recommendation evaluation $key is invalid.');
  }
  return parsed.toUtc();
}
