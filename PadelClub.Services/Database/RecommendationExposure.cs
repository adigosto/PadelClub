using System;

namespace PadelClub.Services.Database;

/// <summary>
/// One server-recorded recommendation impression. This is deliberately an
/// aggregate-friendly interaction record: it captures the ranked item and
/// later player actions, but never stores the raw purchase history used to
/// generate the recommendation.
/// </summary>
public sealed class RecommendationExposure
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public int UserId { get; set; }

    public int ProductId { get; set; }

    /// <summary>
    /// Immutable server-owned classification calculated when the exposure is
    /// created. It is intentionally not supplied by the client and prevents
    /// demo, test, admin, and otherwise unverified traffic from becoming
    /// operational online-impact evidence later.
    /// </summary>
    public RecommendationTelemetrySource TelemetrySource { get; set; } =
        RecommendationTelemetrySource.Unverified;

    public string AlgorithmVersion { get; set; } = string.Empty;

    public string Strategy { get; set; } = string.Empty;

    public int Rank { get; set; }

    public DateTime ServedAtUtc { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Set only by the authenticated owner through the recommendation click
    /// endpoint. It is not inferred from a page render.
    /// </summary>
    public DateTime? ClickedAtUtc { get; set; }

    /// <summary>
    /// A checkout that followed an owned, clicked exposure in the bounded
    /// attribution window. Delivery is evaluated from the linked order rather
    /// than claimed at checkout time.
    /// </summary>
    public int? PurchasedOrderId { get; set; }

    public DateTime? PurchasedAtUtc { get; set; }

    /// <summary>
    /// Optional immutable link to a prospective, server-randomized experiment
    /// assignment. Historic and descriptive-only rows intentionally remain
    /// null and are never retrofitted into an experiment cohort.
    /// </summary>
    public Guid? ExperimentAssignmentId { get; set; }

    public User User { get; set; } = null!;

    public Product Product { get; set; } = null!;

    public Order? PurchasedOrder { get; set; }

    public RecommendationExperimentAssignment? ExperimentAssignment { get; set; }
}
