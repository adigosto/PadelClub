using System;

namespace PadelClub.Model.Requests;

/// <summary>
/// Defines a reproducible historical window for evaluating product recommendations.
/// Both bounds use a half-open interval: [cutoffUtc, endUtc).
/// </summary>
public sealed class RecommendationEvaluationRequest
{
    public DateTimeOffset? CutoffUtc { get; set; }

    public DateTimeOffset? EndUtc { get; set; }

    public int K { get; set; } = 6;
}
