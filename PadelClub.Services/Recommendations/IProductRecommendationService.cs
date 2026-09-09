using System;
using System.Collections.Generic;
using PadelClub.Model.Responses;

namespace PadelClub.Services.Recommendations;

public interface IProductRecommendationService
{
    Task<IReadOnlyList<ProductRecommendationResponse>> GetForUserAsync(
        int userId,
        int limit,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Records an intentional interaction with a recommendation owned by the
    /// authenticated player. Returns false rather than exposing another
    /// player's opaque identifier.
    /// </summary>
    Task<bool> RecordClickAsync(
        int userId,
        Guid exposureId,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Associates a matching, recent, clicked recommendation exposure with a
    /// newly persisted customer checkout. Invalid or stale client-supplied
    /// exposure identifiers are ignored and never affect the order itself.
    /// The caller saves the shared DbContext in its existing transaction.
    /// </summary>
    Task RecordCheckoutAttributionsAsync(
        int userId,
        int orderId,
        IReadOnlyCollection<RecommendationCheckoutAttribution> attributions,
        CancellationToken cancellationToken = default);
}

public sealed record RecommendationCheckoutAttribution(Guid ExposureId, int ProductId);
