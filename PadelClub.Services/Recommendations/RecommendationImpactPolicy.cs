namespace PadelClub.Services.Recommendations;

/// <summary>
/// Conservative gates for descriptive online recommendation monitoring. The
/// thresholds make a report useful for exam/demo readiness without turning a
/// small convenience sample into a causal-impact claim.
/// </summary>
public static class RecommendationImpactPolicy
{
    public const string Version = "online-impact-readiness-v2";
    public const int AttributionWindowDays = 7;
    public const int MinimumObservationDays = 14;
    public const int MinimumExposures = 100;
    public const int MinimumDistinctUsers = 30;

    /// <summary>
    /// A click is valid only when the server-recorded interaction occurred
    /// after the exposure and before its attribution deadline. This rule is
    /// used both before persisting a click and while reading historical rows,
    /// so an old or malformed row cannot rewrite a closed funnel later.
    /// </summary>
    public static bool HasValidClickTiming(DateTime servedAtUtc, DateTime? clickedAtUtc)
    {
        if (clickedAtUtc is not { } clickedAt)
            return false;

        return clickedAt >= servedAtUtc &&
               clickedAt <= servedAtUtc.AddDays(AttributionWindowDays);
    }

    public static bool CanRecordClick(DateTime servedAtUtc, DateTime nowUtc) =>
        nowUtc >= servedAtUtc && nowUtc <= servedAtUtc.AddDays(AttributionWindowDays);

    public static bool HasValidAttributionTiming(
        DateTime servedAtUtc,
        DateTime? clickedAtUtc,
        DateTime? purchasedAtUtc)
    {
        if (purchasedAtUtc is not { } purchasedAt ||
            clickedAtUtc is not { } clickedAt ||
            !HasValidClickTiming(servedAtUtc, clickedAtUtc))
        {
            return false;
        }

        return purchasedAt >= clickedAt &&
               purchasedAt <= servedAtUtc.AddDays(AttributionWindowDays);
    }
}
