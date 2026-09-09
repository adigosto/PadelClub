namespace PadelClub.Model.Requests;

/// <summary>
/// Explicit player choice for prospective recommendation-experiment telemetry.
/// </summary>
public sealed class RecommendationAnalyticsConsentRequest
{
    public bool IsGranted { get; set; }
}
