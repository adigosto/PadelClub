namespace PadelClub.Services.Recommendations;

/// <summary>
/// A deterministic item-to-item collaborative filter for implicit purchase data.
/// Product vectors are built from other customers' completed purchase histories;
/// cosine similarity is shrinkage-adjusted to avoid over-promoting one-off pairs.
/// </summary>
public static class ItemBasedCollaborativeRanker
{
    public const string Version = "item-cf-cosine-v1";

    private const double HalfLifeDays = 180d;
    private const double SupportShrinkage = 3d;

    /// <summary>
    /// Prepares reusable state for evaluating many customers against one fixed
    /// historical snapshot. The online serving path should continue to call
    /// <see cref="Rank"/> directly.
    /// </summary>
    public static PreparedItemBasedCollaborativeRanker Prepare(
        IEnumerable<PurchaseSignal> purchaseSignals,
        DateTime utcNow) => new(purchaseSignals, utcNow);

    public static IReadOnlyList<CollaborativeProductScore> Rank(
        int targetUserId,
        IEnumerable<PurchaseSignal> purchaseSignals,
        IEnumerable<RecommendationCandidate> candidates,
        DateTime utcNow)
    {
        var candidateIds = candidates
            .Select(x => x.ProductId)
            .Where(x => x > 0)
            .Distinct()
            .ToHashSet();

        if (candidateIds.Count == 0)
            return Array.Empty<CollaborativeProductScore>();

        var userItemWeights = purchaseSignals
            .Where(x => x.UserId > 0 && x.ProductId > 0 && x.Quantity > 0)
            .Select(x => new WeightedPurchase(x.UserId, x.ProductId, SignalWeight(x, utcNow)))
            .Where(x => x.Weight > 0d)
            .GroupBy(x => (x.UserId, x.ProductId))
            .Select(group => new WeightedPurchase(
                group.Key.UserId,
                group.Key.ProductId,
                group.Sum(x => x.Weight)))
            .GroupBy(x => x.UserId)
            .ToDictionary(
                group => group.Key,
                group => group.ToDictionary(x => x.ProductId, x => x.Weight));

        if (!userItemWeights.TryGetValue(targetUserId, out var targetHistory) || targetHistory.Count == 0)
            return Array.Empty<CollaborativeProductScore>();

        var peerItemVectors = new Dictionary<int, Dictionary<int, double>>();
        foreach (var user in userItemWeights)
        {
            if (user.Key == targetUserId)
                continue;

            foreach (var item in user.Value)
            {
                if (!peerItemVectors.TryGetValue(item.Key, out var vector))
                {
                    vector = new Dictionary<int, double>();
                    peerItemVectors[item.Key] = vector;
                }

                vector[user.Key] = item.Value;
            }
        }

        var ownedProductIds = targetHistory.Keys.ToHashSet();
        var results = new List<CollaborativeProductScore>();

        foreach (var candidateProductId in candidateIds.Where(x => !ownedProductIds.Contains(x)))
        {
            if (!peerItemVectors.TryGetValue(candidateProductId, out var candidateVector))
                continue;

            var candidateNorm = Norm(candidateVector.Values);
            if (candidateNorm <= 0d)
                continue;

            var score = 0d;
            var strongestContribution = 0d;
            var becauseProductId = 0;
            var supportingCustomers = 0;

            foreach (var source in targetHistory)
            {
                if (!peerItemVectors.TryGetValue(source.Key, out var sourceVector))
                    continue;

                var commonCustomers = sourceVector.Keys
                    .Where(candidateVector.ContainsKey)
                    .ToList();
                if (commonCustomers.Count == 0)
                    continue;

                var sourceNorm = Norm(sourceVector.Values);
                if (sourceNorm <= 0d)
                    continue;

                var dotProduct = commonCustomers.Sum(customerId =>
                    sourceVector[customerId] * candidateVector[customerId]);
                var cosineSimilarity = dotProduct / (sourceNorm * candidateNorm);
                var shrinkage = commonCustomers.Count / (commonCustomers.Count + SupportShrinkage);
                var contribution = source.Value * cosineSimilarity * shrinkage;
                if (contribution <= 0d)
                    continue;

                score += contribution;
                if (contribution > strongestContribution)
                {
                    strongestContribution = contribution;
                    becauseProductId = source.Key;
                    supportingCustomers = commonCustomers.Count;
                }
            }

            if (score > 0d && becauseProductId > 0)
            {
                results.Add(new CollaborativeProductScore(
                    candidateProductId,
                    score,
                    becauseProductId,
                    supportingCustomers));
            }
        }

        return results
            .OrderByDescending(x => x.Score)
            .ThenByDescending(x => x.SupportingCustomers)
            .ThenBy(x => x.ProductId)
            .ToList();
    }

    private static double SignalWeight(PurchaseSignal signal, DateTime utcNow)
    {
        var purchasedAt = signal.PurchasedAt.Kind == DateTimeKind.Utc
            ? signal.PurchasedAt
            : DateTime.SpecifyKind(signal.PurchasedAt, DateTimeKind.Utc);
        var ageDays = Math.Max(0d, (utcNow - purchasedAt).TotalDays);
        var recency = Math.Exp(-Math.Log(2d) * ageDays / HalfLifeDays);
        return Math.Log(1d + signal.Quantity) * recency;
    }

    private static double Norm(IEnumerable<double> values) => Math.Sqrt(values.Sum(x => x * x));

    private sealed record WeightedPurchase(int UserId, int ProductId, double Weight);
}

public sealed record PurchaseSignal(int UserId, int ProductId, int Quantity, DateTime PurchasedAt);

public sealed record RecommendationCandidate(int ProductId);

public sealed record CollaborativeProductScore(
    int ProductId,
    double Score,
    int BecauseProductId,
    int SupportingCustomers);
