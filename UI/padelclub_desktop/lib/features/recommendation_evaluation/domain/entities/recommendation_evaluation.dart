/// A reproducible historical evaluation of the product recommendation ranker.
///
/// Metric values are nullable by design. The API returns no metric values when
/// the selected window has no warm evaluable users; the UI must show that
/// limitation rather than substitute zeroes.
class RecommendationEvaluation {
  const RecommendationEvaluation({
    required this.evidenceSource,
    required this.evidenceTier,
    required this.inputFingerprintSha256,
    required this.configurationSha256,
    required this.isAvailable,
    required this.isSmallSample,
    required this.protocol,
    required this.algorithmVersion,
    required this.cutoffUtc,
    required this.endUtc,
    required this.k,
    required this.cohort,
    required this.quality,
    required this.collaborativeFiltering,
    required this.popularityBaseline,
    required this.limitations,
    this.unavailableReason,
  });

  final bool isAvailable;
  final bool isSmallSample;
  final String evidenceSource;
  final String evidenceTier;
  final String inputFingerprintSha256;
  final String configurationSha256;
  final String? unavailableReason;
  final String protocol;
  final String algorithmVersion;
  final DateTime cutoffUtc;
  final DateTime endUtc;
  final int k;
  final RecommendationEvaluationCohort cohort;
  final RecommendationEvaluationQuality quality;
  final RecommendationEvaluationMethodMetrics collaborativeFiltering;
  final RecommendationEvaluationMethodMetrics popularityBaseline;
  final List<String> limitations;
}

/// Data-sufficiency evidence for an operational recommendation evaluation.
///
/// A report can be mathematically available while still being a diagnostic
/// rather than a credible quality claim. The API supplies every threshold and
/// failed requirement so the presentation layer cannot hide that distinction.
class RecommendationEvaluationQuality {
  const RecommendationEvaluationQuality({
    required this.policyVersion,
    required this.isMeaningful,
    required this.evidenceTier,
    required this.minimumHistoricalWindowDays,
    required this.minimumReturnMaturityDays,
    required this.minimumDeliveredOrders,
    required this.minimumTrainingSignals,
    required this.minimumHoldoutSignals,
    required this.minimumCandidateProducts,
    required this.minimumEvaluatedUsers,
    required this.unmetRequirements,
    required this.gates,
  });

  final String policyVersion;
  final bool isMeaningful;
  final String evidenceTier;
  final int minimumHistoricalWindowDays;
  final int minimumReturnMaturityDays;
  final int minimumDeliveredOrders;
  final int minimumTrainingSignals;
  final int minimumHoldoutSignals;
  final int minimumCandidateProducts;
  final int minimumEvaluatedUsers;
  final List<String> unmetRequirements;
  final List<RecommendationEvaluationQualityGate> gates;
}

class RecommendationEvaluationQualityGate {
  const RecommendationEvaluationQualityGate({
    required this.name,
    required this.passed,
    required this.observed,
    required this.required,
    required this.detail,
  });

  final String name;
  final bool passed;
  final String observed;
  final String required;
  final String detail;
}

class RecommendationEvaluationCohort {
  const RecommendationEvaluationCohort({
    required this.deliveredOrders,
    required this.excludedSeededDemoOrders,
    required this.excludedUnverifiedLegacyOrders,
    required this.excludedNonOperationalOrders,
    required this.excludedOrdersWithoutDeliveredAt,
    required this.unresolvedApprovedOrRefundedReturns,
    required this.distinctCustomers,
    required this.candidateProductsWithAtLeastTwoDistinctBuyers,
    required this.historicalObservationDays,
    required this.eligibleOrderOrigins,
    required this.trainingOrders,
    required this.holdoutOrders,
    required this.trainingSignals,
    required this.holdoutSignals,
    required this.candidateProducts,
    required this.evaluatedUsers,
    required this.coldStartUsers,
    required this.usersWithoutNovelHoldout,
    required this.excludedHoldoutProductsWithoutTrainingEvidence,
    required this.legacyDeliveryTimestampFallbacks,
  });

  final int deliveredOrders;
  final int excludedSeededDemoOrders;
  final int excludedUnverifiedLegacyOrders;
  final int excludedNonOperationalOrders;
  final int excludedOrdersWithoutDeliveredAt;
  final int unresolvedApprovedOrRefundedReturns;
  final int distinctCustomers;
  final int candidateProductsWithAtLeastTwoDistinctBuyers;
  final int historicalObservationDays;
  final List<String> eligibleOrderOrigins;
  final int trainingOrders;
  final int holdoutOrders;
  final int trainingSignals;
  final int holdoutSignals;
  final int candidateProducts;
  final int evaluatedUsers;
  final int coldStartUsers;
  final int usersWithoutNovelHoldout;
  final int excludedHoldoutProductsWithoutTrainingEvidence;
  final int legacyDeliveryTimestampFallbacks;
}

class RecommendationEvaluationMethodMetrics {
  const RecommendationEvaluationMethodMetrics({
    required this.method,
    required this.precisionAtK,
    required this.recallAtK,
    required this.hitRateAtK,
    required this.meanReciprocalRankAtK,
    required this.normalizedDiscountedCumulativeGainAtK,
    required this.catalogCoverageAtK,
    required this.averageRecommendationsReturned,
    required this.totalHits,
    required this.usersWithRecommendations,
  });

  final String method;
  final double? precisionAtK;
  final double? recallAtK;
  final double? hitRateAtK;
  final double? meanReciprocalRankAtK;
  final double? normalizedDiscountedCumulativeGainAtK;
  final double? catalogCoverageAtK;
  final double? averageRecommendationsReturned;
  final int totalHits;
  final int usersWithRecommendations;
}

/// A saved, immutable administrator evidence record. The embedded report is
/// aggregate-only and must be presented as operational ranking evidence, not a
/// causal customer-conversion claim.
class RecommendationEvaluationRun {
  const RecommendationEvaluationRun({
    required this.runId,
    required this.executedByUserId,
    required this.executedAtUtc,
    required this.evidenceSource,
    required this.evidenceTier,
    required this.inputFingerprintSha256,
    required this.configurationSha256,
    required this.report,
  });

  final String runId;
  final int executedByUserId;
  final DateTime executedAtUtc;
  final String evidenceSource;
  final String evidenceTier;
  final String inputFingerprintSha256;
  final String configurationSha256;
  final RecommendationEvaluation report;
}
