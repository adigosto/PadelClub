using System;

namespace PadelClub.Model.Responses;

/// <summary>
/// Immutable aggregate snapshot of a prospective experiment analysis.
/// </summary>
public sealed class RecommendationExperimentAnalysisRunResponse
{
    public Guid RunId { get; init; }

    public Guid ExperimentId { get; init; }

    public DateTimeOffset ExecutedAtUtc { get; init; }

    public string EvidenceTier { get; init; } = string.Empty;

    public string Protocol { get; init; } = string.Empty;

    public string ConfigurationSha256 { get; init; } = string.Empty;

    public string InputFingerprintSha256 { get; init; } = string.Empty;

    public RecommendationExperimentImpactResponse Report { get; init; } = new();
}
