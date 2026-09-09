using System;
using System.Collections.Generic;

namespace PadelClub.Model.Responses;

/// <summary>
/// Aggregate-only operational collection preflight for recommendation
/// evaluation. It intentionally does not calculate ranking metrics or claim a
/// qualified cohort: a selected, return-matured historical window must still
/// be evaluated through the recommendation evaluation endpoint.
/// </summary>
public sealed class RecommendationCohortReadinessResponse
{
    public DateTimeOffset GeneratedAtUtc { get; set; }

    /// <summary>Always <c>Operational</c>; external benchmark data is never included.</summary>
    public string EvidenceSource { get; set; } = "Operational";

    /// <summary>
    /// One of <c>NoEligibleCohort</c>, <c>DataQualityBlocked</c>,
    /// <c>Collecting</c>, or <c>ReadyForWindowValidation</c>. The final state
    /// is only a collection preflight and is never a quality result.
    /// </summary>
    public string ReadinessState { get; set; } = "NoEligibleCohort";

    /// <summary>
    /// True only when aggregate collection checks are satisfied and there is
    /// enough calendar time to select a matured historical window. It does
    /// not replace the temporal evaluator's split-specific quality gates.
    /// </summary>
    public bool IsReadyForWindowValidation { get; set; }

    /// <summary>
    /// Human-readable explanation of the present collection state. It never
    /// labels a cohort qualified.
    /// </summary>
    public string Summary { get; set; } = string.Empty;

    public DateTimeOffset? FirstEligibleDeliveryUtc { get; set; }

    public DateTimeOffset? LatestEligibleDeliveryUtc { get; set; }

    /// <summary>
    /// The latest possible holdout end whose 30-day return-maturity period has
    /// elapsed. It does not imply sufficient signals in that window.
    /// </summary>
    public DateTimeOffset LatestReturnMaturedEvaluationEndUtc { get; set; }

    /// <summary>
    /// Earliest wall-clock time at which the first observed delivery could
    /// support a 90-day pre-fold history, 28-day holdout, and 30-day return
    /// maturity period. Counts and the actual temporal split still need
    /// validation.
    /// </summary>
    public DateTimeOffset? EarliestTimeOnlyWindowValidationAtUtc { get; set; }

    public RecommendationCohortReadinessCountsResponse Cohort { get; set; } = new();

    /// <summary>
    /// Collection preflight requirements. Entries marked
    /// <c>RequiresEvaluationWindow</c> deliberately remain unassessed here,
    /// because only the fixed historical evaluator can verify them.
    /// </summary>
    public List<RecommendationCohortReadinessRequirementResponse> Requirements { get; set; } = new();

    /// <summary>Practical, non-destructive data-collection next steps.</summary>
    public List<string> NextActions { get; set; } = new();

    /// <summary>Boundaries that prevent this report from overclaiming.</summary>
    public List<string> Limitations { get; set; } = new();
}

/// <summary>
/// Counts are aggregate-only and use active-user orders. They are collection
/// progress, not the evaluator's selected-window totals.
/// </summary>
public sealed class RecommendationCohortReadinessCountsResponse
{
    public int CustomerCheckoutOrders { get; set; }

    public int VerifiedImportOrders { get; set; }

    public int EligibleDeliveredOrders { get; set; }

    public int MaturedEligibleDeliveredOrders { get; set; }

    /// <summary>
    /// Delivered order-item lines with a positive quantity after currently
    /// resolved approved/refunded return quantities are subtracted. This is an
    /// all-time collection count, not a selected evaluation-window signal
    /// total.
    /// </summary>
    public int EligibleRetainedPurchaseSignals { get; set; }

    public int MaturedEligibleRetainedPurchaseSignals { get; set; }

    public int EligibleDistinctCustomers { get; set; }

    public int EligibleDistinctProducts { get; set; }

    public int EligibleProductsWithAtLeastTwoDistinctBuyers { get; set; }

    public int OperationalOrdersAwaitingDelivery { get; set; }

    public int EligibleDeliveredOrdersMissingDeliveredAt { get; set; }

    public int OpenOperationalReturnRequests { get; set; }

    public int ApprovedOrRefundedReturnsMissingResolvedAt { get; set; }

    public int ExcludedSeededDemoOrders { get; set; }

    public int ExcludedUnverifiedLegacyOrders { get; set; }

    public int ExcludedNonOperationalOrders { get; set; }
}

/// <summary>
/// Describes a collection check without pretending that every check can be
/// established before an administrator selects an evaluation window.
/// </summary>
public sealed class RecommendationCohortReadinessRequirementResponse
{
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// <c>Met</c>, <c>Gap</c>, or <c>RequiresEvaluationWindow</c>.
    /// </summary>
    public string Status { get; set; } = string.Empty;

    public string Observed { get; set; } = string.Empty;

    public string Required { get; set; } = string.Empty;

    public string Detail { get; set; } = string.Empty;
}
