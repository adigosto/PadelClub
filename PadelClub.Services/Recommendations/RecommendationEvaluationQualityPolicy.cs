using PadelClub.Model.Responses;

namespace PadelClub.Services.Recommendations;

/// <summary>
/// Turns a calculable backtest into an explicit evidence classification. The
/// rules are intentionally fail-closed: demo, test, admin-created, and
/// unverified legacy orders never become qualified simply because they exist.
/// </summary>
public static class RecommendationEvaluationQualityPolicy
{
    public const string Version = "operational-provenance-sufficiency-v3";
    public const int MinimumHistoricalWindowDays = 28;
    public const int MinimumReturnMaturityDays = 30;
    public const int MinimumDeliveredOrders = 100;
    public const int MinimumDistinctCustomers = 30;
    public const int MinimumTrainingSignals = 500;
    public const int MinimumHoldoutSignals = 100;
    public const int MinimumCandidateProducts = 20;
    public const int MinimumCandidateProductsWithTwoDistinctBuyers = 10;
    public const int MinimumEvaluatedUsers = 50;
    public const int MinimumHistoricalObservationDays = 90;

    public static RecommendationEvaluationQualityAssessment Assess(
        RecommendationEvaluationQualityInput input)
    {
        var gates = new List<RecommendationEvaluationQualityGateResponse>();
        AddGate(
            gates,
            "metrics-available",
            input.IsAvailable,
            input.IsAvailable ? "available" : "unavailable",
            "available",
            "At least one warm user must have retained history before the cutoff and a novel retained holdout purchase.");
        AddGate(
            gates,
            "provenance-only",
            input.OnlyEligibleOriginsContributed,
            input.OnlyEligibleOriginsContributed
                ? "CustomerCheckout / VerifiedImport only"
                : "ineligible origin found",
            "CustomerCheckout / VerifiedImport only",
            "Only explicitly provenance-eligible order origins may contribute; legacy, demo, test, and admin-created rows are excluded.");
        AddGate(
            gates,
            "delivery-timestamps",
            input.EligibleOrdersWithoutDeliveredAt == 0,
            input.EligibleOrdersWithoutDeliveredAt.ToString(),
            "0 missing DeliveredAt",
            "Operational evidence requires a delivery timestamp. CreatedAt is never used as a fallback.");
        AddGate(
            gates,
            "return-resolution-timestamps",
            input.UnresolvedApprovedOrRefundedReturns == 0,
            input.UnresolvedApprovedOrRefundedReturns.ToString(),
            "0 missing ResolvedAt",
            "Approved/refunded returns require ResolvedAt; the request-created timestamp is never substituted for an outcome.");
        AddGate(
            gates,
            "holdout-window",
            input.HistoricalWindow.TotalDays >= MinimumHistoricalWindowDays,
            $"{input.HistoricalWindow.TotalDays:0} days",
            $">= {MinimumHistoricalWindowDays} days",
            "The holdout must span a meaningful fixed historical period.");
        var maturityDays = Math.Max(0d, (input.EvaluatedAtUtc - input.EndUtc).TotalDays);
        AddGate(
            gates,
            "return-maturity",
            maturityDays >= MinimumReturnMaturityDays,
            $"{maturityDays:0} days",
            $">= {MinimumReturnMaturityDays} days",
            "Holdout labels are observed for 30 days after the selected end so later approved/refunded returns can be netted.");
        AddGate(
            gates,
            "eligible-delivered-orders",
            input.DeliveredOrders >= MinimumDeliveredOrders,
            input.DeliveredOrders.ToString(),
            $">= {MinimumDeliveredOrders}",
            "Counts only provenance-eligible delivered orders with DeliveredAt.");
        AddGate(
            gates,
            "distinct-customers",
            input.DistinctCustomers >= MinimumDistinctCustomers,
            input.DistinctCustomers.ToString(),
            $">= {MinimumDistinctCustomers}",
            "Reduces the chance that a few repeat buyers dominate an operational claim.");
        AddGate(
            gates,
            "training-signals",
            input.TrainingSignals >= MinimumTrainingSignals,
            input.TrainingSignals.ToString(),
            $">= {MinimumTrainingSignals}",
            "Uses retained, return-netted training interactions before the cutoff.");
        AddGate(
            gates,
            "holdout-signals",
            input.HoldoutSignals >= MinimumHoldoutSignals,
            input.HoldoutSignals.ToString(),
            $">= {MinimumHoldoutSignals}",
            "Uses retained, return-matured interactions in the holdout.");
        AddGate(
            gates,
            "candidate-products",
            input.CandidateProducts >= MinimumCandidateProducts,
            input.CandidateProducts.ToString(),
            $">= {MinimumCandidateProducts}",
            "Candidates are product interactions observable before the cutoff.");
        AddGate(
            gates,
            "multi-buyer-candidates",
            input.CandidateProductsWithAtLeastTwoDistinctBuyers >= MinimumCandidateProductsWithTwoDistinctBuyers,
            input.CandidateProductsWithAtLeastTwoDistinctBuyers.ToString(),
            $">= {MinimumCandidateProductsWithTwoDistinctBuyers}",
            "Requires enough candidate products to have support from at least two distinct buyers.");
        AddGate(
            gates,
            "warm-evaluable-users",
            input.EvaluatedUsers >= MinimumEvaluatedUsers,
            input.EvaluatedUsers.ToString(),
            $">= {MinimumEvaluatedUsers}",
            "A warm user has retained history and a novel retained product in the holdout.");
        AddGate(
            gates,
            "pre-fold-history",
            input.HistoricalObservationDays >= MinimumHistoricalObservationDays,
            $"{input.HistoricalObservationDays} days",
            $">= {MinimumHistoricalObservationDays} days",
            "Measures observed provenance-eligible history before the evaluation cutoff.");

        var unmetRequirements = gates
            .Where(gate => !gate.Passed)
            .Select(gate => $"{gate.Name}: observed {gate.Observed}; required {gate.Required}. {gate.Detail}")
            .ToArray();
        var isMeaningful = unmetRequirements.Length == 0;
        var evidenceTier = !input.IsAvailable
            ? "Unavailable"
            : isMeaningful ? "Qualified" : "Diagnostic";

        return new RecommendationEvaluationQualityAssessment(
            IsMeaningful: isMeaningful,
            EvidenceTier: evidenceTier,
            Gates: gates,
            UnmetRequirements: unmetRequirements);
    }

    private static void AddGate(
        ICollection<RecommendationEvaluationQualityGateResponse> gates,
        string name,
        bool passed,
        string observed,
        string required,
        string detail) => gates.Add(new RecommendationEvaluationQualityGateResponse
        {
            Name = name,
            Passed = passed,
            Observed = observed,
            Required = required,
            Detail = detail
        });
}

public sealed record RecommendationEvaluationQualityInput(
    bool IsAvailable,
    bool OnlyEligibleOriginsContributed,
    int EligibleOrdersWithoutDeliveredAt,
    int UnresolvedApprovedOrRefundedReturns,
    TimeSpan HistoricalWindow,
    DateTime EndUtc,
    DateTime EvaluatedAtUtc,
    int DeliveredOrders,
    int DistinctCustomers,
    int TrainingSignals,
    int HoldoutSignals,
    int CandidateProducts,
    int CandidateProductsWithAtLeastTwoDistinctBuyers,
    int EvaluatedUsers,
    int HistoricalObservationDays);

public sealed record RecommendationEvaluationQualityAssessment(
    bool IsMeaningful,
    string EvidenceTier,
    IReadOnlyList<RecommendationEvaluationQualityGateResponse> Gates,
    IReadOnlyList<string> UnmetRequirements);
