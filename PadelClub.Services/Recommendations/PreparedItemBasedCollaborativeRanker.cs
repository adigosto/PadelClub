namespace PadelClub.Services.Recommendations;

/// <summary>
/// Reusable item-to-item state for a fixed historical snapshot.
///
/// The player-serving path ranks one customer at a time and keeps using
/// <see cref="ItemBasedCollaborativeRanker.Rank"/>. Offline evaluation ranks a
/// whole cohort against the same snapshot, so this prepared form builds the
/// weighted customer-item vectors and item-pair statistics once per fold.
/// </summary>
public sealed class PreparedItemBasedCollaborativeRanker
{
    private const double SupportShrinkage = 3d;

    private readonly IReadOnlyDictionary<int, IReadOnlyDictionary<int, double>> _weightsByUser;
    private readonly IReadOnlyDictionary<int, double> _normSquaredByProduct;
    private readonly IReadOnlyDictionary<int, IReadOnlyDictionary<int, PairStatistics>> _pairsByProduct;

    internal PreparedItemBasedCollaborativeRanker(
        IEnumerable<PurchaseSignal> purchaseSignals,
        DateTime utcNow)
    {
        var normalizedNow = NormalizeUtc(utcNow);
        var weightsByUser = purchaseSignals
            .Where(x => x.UserId > 0 && x.ProductId > 0 && x.Quantity > 0)
            .Select(x => new WeightedPurchase(x.UserId, x.ProductId, SignalWeight(x, normalizedNow)))
            .Where(x => x.Weight > 0d)
            .GroupBy(x => (x.UserId, x.ProductId))
            .Select(group => new WeightedPurchase(
                group.Key.UserId,
                group.Key.ProductId,
                group.Sum(x => x.Weight)))
            .GroupBy(x => x.UserId)
            .ToDictionary(
                group => group.Key,
                group => (IReadOnlyDictionary<int, double>)group.ToDictionary(
                    x => x.ProductId,
                    x => x.Weight));

        _weightsByUser = weightsByUser;
        var normSquaredByProduct = new Dictionary<int, double>();
        var mutablePairsByProduct = new Dictionary<int, Dictionary<int, PairStatistics>>();
        foreach (var basket in weightsByUser.Values)
        {
            foreach (var item in basket)
            {
                normSquaredByProduct[item.Key] =
                    normSquaredByProduct.GetValueOrDefault(item.Key) + item.Value * item.Value;
            }

            var items = basket.OrderBy(x => x.Key).ToArray();
            for (var left = 0; left < items.Length; left++)
            {
                for (var right = left + 1; right < items.Length; right++)
                {
                    AddPair(
                        mutablePairsByProduct,
                        items[left].Key,
                        items[right].Key,
                        items[left].Value * items[right].Value);
                }
            }
        }

        _normSquaredByProduct = normSquaredByProduct;
        _pairsByProduct = mutablePairsByProduct.ToDictionary(
            group => group.Key,
            group => (IReadOnlyDictionary<int, PairStatistics>)group.Value);
    }

    /// <summary>
    /// Produces the same cosine/support-shrinkage scores as the player ranker
    /// for one customer, using only the snapshot supplied at construction time.
    /// </summary>
    public IReadOnlyList<CollaborativeProductScore> Rank(
        int targetUserId,
        IEnumerable<RecommendationCandidate> candidates)
    {
        var candidateIds = candidates
            .Select(x => x.ProductId)
            .Where(x => x > 0)
            .Distinct()
            .ToHashSet();
        if (candidateIds.Count == 0 ||
            !_weightsByUser.TryGetValue(targetUserId, out var targetHistory) ||
            targetHistory.Count == 0)
        {
            return Array.Empty<CollaborativeProductScore>();
        }

        var ownedProductIds = targetHistory.Keys.ToHashSet();
        var results = new Dictionary<int, MutableScore>();
        foreach (var source in targetHistory)
        {
            var sourceNormSquared = _normSquaredByProduct.GetValueOrDefault(source.Key) -
                                    source.Value * source.Value;
            if (sourceNormSquared <= 0d ||
                !_pairsByProduct.TryGetValue(source.Key, out var relatedProducts))
            {
                continue;
            }

            foreach (var related in relatedProducts)
            {
                var candidateProductId = related.Key;
                if (!candidateIds.Contains(candidateProductId) ||
                    ownedProductIds.Contains(candidateProductId))
                {
                    continue;
                }

                var candidateNormSquared = _normSquaredByProduct.GetValueOrDefault(candidateProductId);
                if (candidateNormSquared <= 0d)
                    continue;

                var cosineSimilarity = related.Value.DotProduct /
                                       Math.Sqrt(sourceNormSquared * candidateNormSquared);
                var shrinkage = related.Value.SupportingCustomers /
                                (related.Value.SupportingCustomers + SupportShrinkage);
                var contribution = source.Value * cosineSimilarity * shrinkage;
                if (contribution <= 0d)
                    continue;

                if (!results.TryGetValue(candidateProductId, out var score))
                {
                    score = new MutableScore();
                    results[candidateProductId] = score;
                }

                score.Value += contribution;
                if (contribution > score.StrongestContribution)
                {
                    score.StrongestContribution = contribution;
                    score.BecauseProductId = source.Key;
                    score.SupportingCustomers = related.Value.SupportingCustomers;
                }
            }
        }

        return results
            .Where(x => x.Value.Value > 0d && x.Value.BecauseProductId > 0)
            .Select(x => new CollaborativeProductScore(
                x.Key,
                x.Value.Value,
                x.Value.BecauseProductId,
                x.Value.SupportingCustomers))
            .OrderByDescending(x => x.Score)
            .ThenByDescending(x => x.SupportingCustomers)
            .ThenBy(x => x.ProductId)
            .ToArray();
    }

    private static void AddPair(
        IDictionary<int, Dictionary<int, PairStatistics>> pairsByProduct,
        int firstProductId,
        int secondProductId,
        double dotProduct)
    {
        AddDirectedPair(pairsByProduct, firstProductId, secondProductId, dotProduct);
        AddDirectedPair(pairsByProduct, secondProductId, firstProductId, dotProduct);
    }

    private static void AddDirectedPair(
        IDictionary<int, Dictionary<int, PairStatistics>> pairsByProduct,
        int sourceProductId,
        int candidateProductId,
        double dotProduct)
    {
        if (!pairsByProduct.TryGetValue(sourceProductId, out var relatedProducts))
        {
            relatedProducts = [];
            pairsByProduct[sourceProductId] = relatedProducts;
        }

        if (!relatedProducts.TryGetValue(candidateProductId, out var pair))
        {
            pair = new PairStatistics();
            relatedProducts[candidateProductId] = pair;
        }

        pair.DotProduct += dotProduct;
        pair.SupportingCustomers++;
    }

    private static double SignalWeight(PurchaseSignal signal, DateTime utcNow)
    {
        var purchasedAt = NormalizeUtc(signal.PurchasedAt);
        var ageDays = Math.Max(0d, (utcNow - purchasedAt).TotalDays);
        var recency = Math.Exp(-Math.Log(2d) * ageDays / 180d);
        return Math.Log(1d + signal.Quantity) * recency;
    }

    private static DateTime NormalizeUtc(DateTime value) =>
        value.Kind == DateTimeKind.Utc
            ? value
            : DateTime.SpecifyKind(value, DateTimeKind.Utc);

    private sealed record WeightedPurchase(int UserId, int ProductId, double Weight);

    private sealed class PairStatistics
    {
        public double DotProduct { get; set; }

        public int SupportingCustomers { get; set; }
    }

    private sealed class MutableScore
    {
        public double Value { get; set; }

        public double StrongestContribution { get; set; }

        public int BecauseProductId { get; set; }

        public int SupportingCustomers { get; set; }
    }
}
