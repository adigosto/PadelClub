using System;

namespace PadelClub.Model.Responses;

/// <summary>
/// A shop product selected by the recommendation engine. <see cref="Score"/> is a
/// ranking value, not a probability of purchase.
/// </summary>
public sealed class ProductRecommendationResponse
{
    /// <summary>
    /// Server-issued identifier for this individual ranked exposure. Clients
    /// may report a click and later attach it to the matching checkout line;
    /// it is not a product identifier and does not authorize any action.
    /// </summary>
    public Guid ExposureId { get; init; }

    public ProductResponse Product { get; init; } = new();
    public double Score { get; init; }
    public string Reason { get; init; } = string.Empty;
    public string Strategy { get; init; } = string.Empty;
    public bool IsFallback { get; init; }
    public string AlgorithmVersion { get; init; } = string.Empty;
    public string? BecauseProductName { get; init; }
    public int SupportingCustomers { get; init; }
}
