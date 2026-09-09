using System;
using System.Collections.Generic;

namespace PadelClub.Model.Responses;

/// <summary>
/// A reproducible, historical backtest of the online product recommendation ranker.
/// Metrics are null when the selected window has no warm evaluable users.
/// </summary>
public sealed class RecommendationEvaluationResponse
{
    /// <summary>
    /// The source boundary for this report. The application currently returns
    /// only <c>Operational</c> reports from this endpoint; external benchmark
    /// results stay in their separately documented artifact.
    /// </summary>
    public string EvidenceSource { get; set; } = "Operational";

    /// <summary>
    /// <c>Unavailable</c>, <c>Diagnostic</c>, or <c>Qualified</c>. A qualified
    /// value means the returned operational cohort passed every declared gate;
    /// it does not claim causal business impact.
    /// </summary>
    public string EvidenceTier { get; set; } = "Unavailable";

    /// <summary>
    /// SHA-256 over canonical, sorted non-persisted interaction/return tuples
    /// used for this calculation. It allows later evidence comparison without
    /// writing raw customer history into an evaluation record.
    /// </summary>
    public string InputFingerprintSha256 { get; set; } = string.Empty;

    /// <summary>SHA-256 over the protocol and locked evaluator configuration.</summary>
    public string ConfigurationSha256 { get; set; } = string.Empty;

    public bool IsAvailable { get; set; }

    public bool IsSmallSample { get; set; }

    public string? UnavailableReason { get; set; }

    public string Protocol { get; set; } = string.Empty;

    public string AlgorithmVersion { get; set; } = string.Empty;

    public DateTimeOffset CutoffUtc { get; set; }

    public DateTimeOffset EndUtc { get; set; }

    public int K { get; set; }

    public RecommendationEvaluationCohortResponse Cohort { get; set; } = new();

    /// <summary>
    /// Explicit operational data-sufficiency gates. A calculable diagnostic is
    /// not automatically a meaningful recommendation-quality claim.
    /// </summary>
    public RecommendationEvaluationQualityResponse Quality { get; set; } = new();

    public RecommendationEvaluationMethodMetricsResponse CollaborativeFiltering { get; set; } = new();

    public RecommendationEvaluationMethodMetricsResponse PopularityBaseline { get; set; } = new();

    public List<string> Limitations { get; set; } = new();
}

public sealed class RecommendationEvaluationCohortResponse
{
    /// <summary>
    /// Operational delivered orders in the evaluator's historical input, ending
    /// at <c>EndUtc</c>. Later purchases are not part of this backtest.
    /// </summary>
    public int DeliveredOrders { get; set; }

    /// <summary>
    /// Delivered orders intentionally excluded because they were created by
    /// the local development seed. They must not become quality evidence.
    /// </summary>
    public int ExcludedSeededDemoOrders { get; set; }

    /// <summary>
    /// Delivered legacy rows whose source cannot be established. They remain
    /// operational history but are not eligible for recommendation evidence.
    /// </summary>
    public int ExcludedUnverifiedLegacyOrders { get; set; }

    /// <summary>
    /// Test and administrator-created rows deliberately excluded from the
    /// provenance-backed cohort.
    /// </summary>
    public int ExcludedNonOperationalOrders { get; set; }

    /// <summary>
    /// Customer-checkout/import rows omitted because they lack a true delivery
    /// timestamp. The evaluator never falls back to CreatedAt for evidence.
    /// </summary>
    public int ExcludedOrdersWithoutDeliveredAt { get; set; }

    /// <summary>
    /// Approved/refunded return records omitted from label netting because they
    /// lack ResolvedAt. The evaluator never substitutes CreatedAt for a return
    /// outcome timestamp.
    /// </summary>
    public int UnresolvedApprovedOrRefundedReturns { get; set; }

    public int DistinctCustomers { get; set; }

    public int CandidateProductsWithAtLeastTwoDistinctBuyers { get; set; }

    public int HistoricalObservationDays { get; set; }

    public List<string> EligibleOrderOrigins { get; set; } = new();

    public int TrainingOrders { get; set; }

    public int HoldoutOrders { get; set; }

    public int TrainingSignals { get; set; }

    public int HoldoutSignals { get; set; }

    public int CandidateProducts { get; set; }

    public int EvaluatedUsers { get; set; }

    public int ColdStartUsers { get; set; }

    public int UsersWithoutNovelHoldout { get; set; }

    public int ExcludedHoldoutProductsWithoutTrainingEvidence { get; set; }

    public int LegacyDeliveryTimestampFallbacks { get; set; }
}

public sealed class RecommendationEvaluationQualityResponse
{
    public string PolicyVersion { get; set; } = string.Empty;

    public bool IsMeaningful { get; set; }

    public string EvidenceTier { get; set; } = "Unavailable";

    public int MinimumHistoricalWindowDays { get; set; }

    public int MinimumReturnMaturityDays { get; set; }

    public int MinimumDeliveredOrders { get; set; }

    public int MinimumTrainingSignals { get; set; }

    public int MinimumHoldoutSignals { get; set; }

    public int MinimumCandidateProducts { get; set; }

    public int MinimumEvaluatedUsers { get; set; }

    public List<string> UnmetRequirements { get; set; } = new();

    public List<RecommendationEvaluationQualityGateResponse> Gates { get; set; } = new();
}

/// <summary>
/// A self-describing quality gate. Values are strings so a gate can honestly
/// show a count, a duration, or an explicit provenance rule without hiding the
/// type of observation behind an ambiguous number.
/// </summary>
public sealed class RecommendationEvaluationQualityGateResponse
{
    public string Name { get; set; } = string.Empty;

    public bool Passed { get; set; }

    public string Observed { get; set; } = string.Empty;

    public string Required { get; set; } = string.Empty;

    public string Detail { get; set; } = string.Empty;
}

/// <summary>
/// Immutable administrative evidence record. Its embedded report contains only
/// aggregate metrics, quality gates, and hashes—never raw customer rows.
/// </summary>
public sealed class RecommendationEvaluationRunResponse
{
    public Guid RunId { get; set; }

    public int ExecutedByUserId { get; set; }

    public DateTimeOffset ExecutedAtUtc { get; set; }

    public string EvidenceSource { get; set; } = "Operational";

    public string EvidenceTier { get; set; } = "Unavailable";

    public string InputFingerprintSha256 { get; set; } = string.Empty;

    public string ConfigurationSha256 { get; set; } = string.Empty;

    public RecommendationEvaluationResponse Report { get; set; } = new();
}

public sealed class RecommendationEvaluationMethodMetricsResponse
{
    public string Method { get; set; } = string.Empty;

    public double? PrecisionAtK { get; set; }

    public double? RecallAtK { get; set; }

    public double? HitRateAtK { get; set; }

    public double? MeanReciprocalRankAtK { get; set; }

    public double? NormalizedDiscountedCumulativeGainAtK { get; set; }

    public double? CatalogCoverageAtK { get; set; }

    public double? AverageRecommendationsReturned { get; set; }

    public int TotalHits { get; set; }

    public int UsersWithRecommendations { get; set; }
}
