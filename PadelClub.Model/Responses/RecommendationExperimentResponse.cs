using System;

namespace PadelClub.Model.Responses;

/// <summary>
/// Safe administrator-facing description of the fixed prospective experiment.
/// No participant identities or assignments are exposed.
/// </summary>
public sealed class RecommendationExperimentResponse
{
    public Guid Id { get; init; }

    public string ExperimentKey { get; init; } = string.Empty;

    public string Status { get; init; } = string.Empty;

    public DateTimeOffset CreatedAtUtc { get; init; }

    public DateTimeOffset? StartedAtUtc { get; init; }

    public DateTimeOffset? ClosedAtUtc { get; init; }

    public string Protocol { get; init; } = string.Empty;

    public string TreatmentAlgorithmVersion { get; init; } = string.Empty;

    public string ControlAlgorithmVersion { get; init; } = string.Empty;

    public string TreatmentStrategy { get; init; } = string.Empty;

    public string ControlStrategy { get; init; } = string.Empty;

    public int TreatmentAllocationPercent { get; init; }

    public int RecommendationLimit { get; init; }

    public int AttributionWindowDays { get; init; }

    public int ReturnMaturityDays { get; init; }

    public string ConfigurationSha256 { get; init; } = string.Empty;
}
