using System.Globalization;

namespace PadelClub.Services.Recommendations;

/// <summary>
/// Locked protocol for the first prospective PadelClub recommendation A/B
/// experiment. Values are persisted in every experiment definition so a later
/// code change cannot rewrite the protocol that was actually served.
/// </summary>
public static class RecommendationExperimentPolicy
{
    public const string ExperimentKey = "product-recommendation-cf-vs-popularity-v1";
    public const string Protocol = "sticky-user-ab-cf-vs-popularity-v1";
    public const string TreatmentStrategy = "experiment-collaborative-filtering-treatment";
    public const string ControlStrategy = "experiment-popularity-control";
    public const int TreatmentAllocationPercent = 50;
    public const int RecommendationLimit = 6;
    public const int AttributionWindowDays = RecommendationImpactPolicy.AttributionWindowDays;
    public const int ReturnMaturityDays = 30;
    public const int MinimumServedUsersPerVariant = 50;
    public const int MinimumExposuresPerVariant = 100;
    public const int MinimumObservationDays = 14;
    public const string ConfidenceIntervalMethod = "newcombe-wilson-95-v1";
    public const string ConsentPolicyVersion = "recommendation-analytics-consent-v1";

    public static string ConfigurationMaterial => string.Join(
        "|",
        ExperimentKey,
        Protocol,
        ItemBasedCollaborativeRanker.Version,
        PopularityRecommendationRanker.Version,
        TreatmentStrategy,
        ControlStrategy,
        TreatmentAllocationPercent.ToString(CultureInfo.InvariantCulture),
        RecommendationLimit.ToString(CultureInfo.InvariantCulture),
        AttributionWindowDays.ToString(CultureInfo.InvariantCulture),
        ReturnMaturityDays.ToString(CultureInfo.InvariantCulture),
        MinimumServedUsersPerVariant.ToString(CultureInfo.InvariantCulture),
        MinimumExposuresPerVariant.ToString(CultureInfo.InvariantCulture),
        MinimumObservationDays.ToString(CultureInfo.InvariantCulture),
        "all-assigned-users-denominator-v1",
        "actual-mature-serving-span-v1",
        ConfidenceIntervalMethod);
}
