using System;
using System.Collections.Generic;

namespace PadelClub.Model.Responses;

/// <summary>
/// Aggregate, descriptive monitoring for recommendation impressions. It is
/// explicitly not an A/B test or a causal-impact claim.
/// </summary>
public sealed class RecommendationImpactResponse
{
    public DateTimeOffset FromUtc { get; init; }

    public DateTimeOffset ToUtc { get; init; }

    public string EvidenceTier { get; init; } = "Collecting";

    public bool IsMature { get; init; }

    public int AttributionWindowDays { get; init; }

    public int MinimumObservationDays { get; init; }

    public int MinimumExposures { get; init; }

    public int MinimumDistinctUsers { get; init; }

    public int Exposures { get; init; }

    /// <summary>
    /// Count of server-stamped demo, test, administrator, unverified, or
    /// non-production exposures omitted from every online-impact metric.
    /// </summary>
    public int ExcludedNonOperationalExposures { get; init; }

    public int DistinctUsers { get; init; }

    public int ClickedExposures { get; init; }

    /// <summary>
    /// Historical operational rows with a click timestamp outside the bounded
    /// server interaction window. They are never counted in CTR or conversion.
    /// New clicks with this timing are rejected before persistence.
    /// </summary>
    public int InvalidClickTimingExposures { get; init; }

    public int AttributedCheckouts { get; init; }

    public int AttributedDeliveredOrders { get; init; }

    public int AttributedCancelledOrders { get; init; }

    public decimal AttributedDeliveredRevenue { get; init; }

    public double? ClickThroughRate { get; init; }

    public double? CheckoutConversionRate { get; init; }

    public double? DeliveredConversionRate { get; init; }

    public int ObservationDays { get; init; }

    public IReadOnlyList<string> UnmetRequirements { get; init; } = Array.Empty<string>();

    public IReadOnlyList<string> Limitations { get; init; } = Array.Empty<string>();
}
