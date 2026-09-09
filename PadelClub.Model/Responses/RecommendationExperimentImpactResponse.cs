using System;
using System.Collections.Generic;

namespace PadelClub.Model.Responses;

/// <summary>
/// Aggregate-only, prospective A/B analysis. A causal point estimate stays
/// null until all pre-registered gates are met; a collecting report is not a
/// result and must never be interpreted as zero lift.
/// </summary>
public sealed class RecommendationExperimentImpactResponse
{
    public Guid ExperimentId { get; init; }

    public string ExperimentKey { get; init; } = string.Empty;

    public string Status { get; init; } = string.Empty;

    public DateTimeOffset GeneratedAtUtc { get; init; }

    public DateTimeOffset? StartedAtUtc { get; init; }

    public DateTimeOffset? ClosedAtUtc { get; init; }

    public string Protocol { get; init; } = string.Empty;

    public string EvidenceTier { get; init; } = "Collecting";

    public bool IsCausalEstimateAvailable { get; init; }

    public string PrimaryOutcomeDefinition { get; init; } = string.Empty;

    public string ConfidenceIntervalMethod { get; init; } = string.Empty;

    public int AttributionWindowDays { get; init; }

    public int MinimumServedUsersPerVariant { get; init; }

    public int MinimumExposuresPerVariant { get; init; }

    public int MinimumObservationDays { get; init; }

    public RecommendationExperimentArmResponse Control { get; init; } = new();

    public RecommendationExperimentArmResponse Treatment { get; init; } = new();

    /// <summary>Treatment rate minus control rate. Null while collecting.</summary>
    public double? AbsoluteLift { get; init; }

    public double? RelativeLift { get; init; }

    public double? AbsoluteLiftConfidenceIntervalLower { get; init; }

    public double? AbsoluteLiftConfidenceIntervalUpper { get; init; }

    public IReadOnlyList<RecommendationExperimentRequirementResponse> UnmetRequirements { get; init; } =
        Array.Empty<RecommendationExperimentRequirementResponse>();

    public IReadOnlyList<string> Limitations { get; init; } = Array.Empty<string>();
}

public sealed class RecommendationExperimentArmResponse
{
    public string Variant { get; init; } = string.Empty;

    public int AssignedUsers { get; init; }

    /// <summary>Distinct assigned users with at least one fully attributed-window-matured exposure.</summary>
    public int MaturedServedUsers { get; init; }

    public int MaturedExposures { get; init; }

    public int ValidClickedExposures { get; init; }

    public int UsersWithAttributedCheckout { get; init; }

    public double? PrimaryOutcomeRate { get; init; }
}

public sealed class RecommendationExperimentRequirementResponse
{
    public string Name { get; init; } = string.Empty;

    public string Observed { get; init; } = string.Empty;

    public string Required { get; init; } = string.Empty;

    public string Detail { get; init; } = string.Empty;
}
