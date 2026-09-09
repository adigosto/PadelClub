using System;

namespace PadelClub.Model.Responses;

/// <summary>
/// The authenticated player's current recommendation-analytics choice.
/// </summary>
public sealed class RecommendationAnalyticsConsentResponse
{
    public bool IsGranted { get; init; }

    public DateTimeOffset? GrantedAtUtc { get; init; }

    public DateTimeOffset? RevokedAtUtc { get; init; }

    public string PolicyVersion { get; init; } = string.Empty;
}
