namespace PadelClub.Services.Recommendations;

/// <summary>
/// A deterministic, non-personalized recommendation baseline. Products are
/// ranked by the number of distinct customers with a retained purchase signal.
/// It is intentionally independent of quantity, recency, and input ordering so
/// it can be used as a stable experiment control.
/// </summary>
public static class PopularityRecommendationRanker
{
    public const string Version = "popularity-distinct-buyers-v1";

    /// <summary>
    /// Ranks the supplied candidate products, excluding products already owned by
    /// the target customer. Candidates with no retained buyers are included at
    /// the end so a caller can still fill a deterministic recommendation list.
    /// </summary>
    public static IReadOnlyList<PopularityProductScore> Rank(
        int targetUserId,
        IEnumerable<PurchaseSignal> purchaseSignals,
        IEnumerable<RecommendationCandidate> candidates)
    {
        ArgumentNullException.ThrowIfNull(purchaseSignals);
        ArgumentNullException.ThrowIfNull(candidates);

        var validSignals = purchaseSignals
            .Where(signal => signal.UserId > 0 && signal.ProductId > 0 && signal.Quantity > 0)
            .ToArray();
        var candidateIds = candidates
            .Select(candidate => candidate.ProductId)
            .Where(productId => productId > 0)
            .Distinct()
            .ToArray();
        if (candidateIds.Length == 0)
            return Array.Empty<PopularityProductScore>();

        var ownedProductIds = validSignals
            .Where(signal => signal.UserId == targetUserId)
            .Select(signal => signal.ProductId)
            .ToHashSet();
        var buyerCountsByProduct = validSignals
            .GroupBy(signal => signal.ProductId)
            .ToDictionary(
                group => group.Key,
                group => group.Select(signal => signal.UserId).Distinct().Count());

        return candidateIds
            .Where(productId => !ownedProductIds.Contains(productId))
            .Select(productId =>
            {
                var supportingCustomers = buyerCountsByProduct.GetValueOrDefault(productId);
                return new PopularityProductScore(
                    productId,
                    Score: supportingCustomers,
                    SupportingCustomers: supportingCustomers);
            })
            .OrderByDescending(score => score.SupportingCustomers)
            .ThenBy(score => score.ProductId)
            .ToArray();
    }
}

/// <summary>
/// A popularity score whose value is exactly the number of distinct retained
/// buyers supporting the product. The double score shape matches the
/// collaborative ranker's score for callers that select an algorithm at runtime.
/// </summary>
public sealed record PopularityProductScore(
    int ProductId,
    double Score,
    int SupportingCustomers);
