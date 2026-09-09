namespace PadelClub.Services.Recommendations;

/// <summary>
/// Pure, deterministic ranking evaluation. Its caller supplies already-split,
/// net-retained interactions so no wall-clock state or database details leak into
/// the calculation.
/// </summary>
public static class TemporalRecommendationEvaluator
{
    public const string Protocol = "global-temporal-future-basket-v1";

    public static RecommendationEvaluationReport Evaluate(
        IEnumerable<TemporalPurchaseSignal> trainingSignals,
        IEnumerable<TemporalPurchaseSignal> holdoutSignals,
        IEnumerable<int> candidateProductIds,
        DateTime cutoffUtc,
        int topK)
    {
        if (topK is < 1 or > 12)
            throw new ArgumentOutOfRangeException(nameof(topK), "K must be between 1 and 12.");

        var cutoff = NormalizeUtc(cutoffUtc);
        var training = trainingSignals
            .Where(x => x.Quantity > 0)
            .Select(x => x with { PurchasedAt = NormalizeUtc(x.PurchasedAt) })
            .ToList();
        var holdout = holdoutSignals
            .Where(x => x.Quantity > 0)
            .Select(x => x with { PurchasedAt = NormalizeUtc(x.PurchasedAt) })
            .ToList();

        if (training.Any(x => x.PurchasedAt >= cutoff))
            throw new ArgumentException("Training interactions must precede the cutoff.", nameof(trainingSignals));
        if (holdout.Any(x => x.PurchasedAt < cutoff))
            throw new ArgumentException("Holdout interactions must start at the cutoff.", nameof(holdoutSignals));

        var candidates = candidateProductIds
            .Where(x => x > 0)
            .Distinct()
            .OrderBy(x => x)
            .ToArray();
        if (candidates.Length == 0)
            return RecommendationEvaluationReport.Unavailable(
                "No product interactions existed before the selected cutoff.",
                candidates.Length);

        var trainingPurchaseSignals = training
            .Select(x => new PurchaseSignal(x.UserId, x.ProductId, x.Quantity, x.PurchasedAt))
            .ToArray();
        var preparedCollaborativeRanker = ItemBasedCollaborativeRanker.Prepare(
            trainingPurchaseSignals,
            cutoff);
        var candidateSet = candidates.ToHashSet();
        var ownedByUser = training
            .GroupBy(x => x.UserId)
            .ToDictionary(
                group => group.Key,
                group => group.Select(x => x.ProductId).ToHashSet());
        var allHoldoutByUser = holdout
            .GroupBy(x => x.UserId)
            .ToDictionary(
                group => group.Key,
                group => group.Select(x => x.ProductId).ToHashSet());
        var popularity = BuildPopularityRanking(training, candidates);
        var collaborative = new MetricAccumulator();
        var baseline = new MetricAccumulator();
        var evaluatedUsers = 0;
        var coldStartUsers = 0;
        var usersWithoutNovelHoldout = 0;
        var excludedHoldoutProducts = 0;

        foreach (var holdoutUser in allHoldoutByUser)
        {
            if (!ownedByUser.TryGetValue(holdoutUser.Key, out var ownedProducts) || ownedProducts.Count == 0)
            {
                coldStartUsers++;
                continue;
            }

            var relevantProducts = holdoutUser.Value
                .Where(candidateSet.Contains)
                .Where(productId => !ownedProducts.Contains(productId))
                .ToHashSet();
            excludedHoldoutProducts += holdoutUser.Value.Count(productId => !candidateSet.Contains(productId));

            if (relevantProducts.Count == 0)
            {
                usersWithoutNovelHoldout++;
                continue;
            }

            evaluatedUsers++;
            var availableCandidates = candidates
                .Where(productId => !ownedProducts.Contains(productId))
                .ToArray();
            var collaborativeRanking = preparedCollaborativeRanker
                .Rank(
                    holdoutUser.Key,
                    availableCandidates.Select(productId => new RecommendationCandidate(productId)))
                .Select(x => x.ProductId)
                .Take(topK)
                .ToArray();
            var popularityRanking = popularity
                .Where(productId => !ownedProducts.Contains(productId))
                .Take(topK)
                .ToArray();

            collaborative.Add(collaborativeRanking, relevantProducts, availableCandidates.Length, topK);
            baseline.Add(popularityRanking, relevantProducts, availableCandidates.Length, topK);
        }

        if (evaluatedUsers == 0)
        {
            return RecommendationEvaluationReport.Unavailable(
                "No users had both retained history before the cutoff and a new retained purchase in the holdout window.",
                candidates.Length,
                coldStartUsers,
                usersWithoutNovelHoldout,
                excludedHoldoutProducts);
        }

        return new RecommendationEvaluationReport(
            IsAvailable: true,
            UnavailableReason: null,
            CandidateProducts: candidates.Length,
            EvaluatedUsers: evaluatedUsers,
            ColdStartUsers: coldStartUsers,
            UsersWithoutNovelHoldout: usersWithoutNovelHoldout,
            ExcludedHoldoutProductsWithoutTrainingEvidence: excludedHoldoutProducts,
            CollaborativeFiltering: collaborative.ToResult(evaluatedUsers, candidates.Length),
            PopularityBaseline: baseline.ToResult(evaluatedUsers, candidates.Length));
    }

    private static IReadOnlyList<int> BuildPopularityRanking(
        IReadOnlyList<TemporalPurchaseSignal> training,
        IReadOnlyList<int> candidates)
    {
        var buyersByProduct = training
            .GroupBy(x => x.ProductId)
            .ToDictionary(group => group.Key, group => group.Select(x => x.UserId).Distinct().Count());

        return candidates
            .OrderByDescending(productId => buyersByProduct.GetValueOrDefault(productId))
            .ThenBy(productId => productId)
            .ToArray();
    }

    private static DateTime NormalizeUtc(DateTime value) =>
        value.Kind == DateTimeKind.Utc
            ? value
            : DateTime.SpecifyKind(value, DateTimeKind.Utc);

    private sealed class MetricAccumulator
    {
        private double _precision;
        private double _recall;
        private double _hitRate;
        private double _mrr;
        private double _ndcg;
        private double _returned;
        private int _totalHits;
        private int _usersWithRecommendations;
        private readonly HashSet<int> _recommendedProducts = [];

        public void Add(
            IReadOnlyList<int> ranking,
            IReadOnlySet<int> relevantProducts,
            int candidateCount,
            int topK)
        {
            var shown = ranking.Take(topK).ToArray();
            var hits = shown.Count(relevantProducts.Contains);
            var denominator = Math.Min(topK, candidateCount);

            _precision += denominator == 0 ? 0d : (double)hits / denominator;
            _recall += (double)hits / relevantProducts.Count;
            _hitRate += hits > 0 ? 1d : 0d;
            _mrr += ReciprocalRank(shown, relevantProducts);
            _ndcg += NormalizedDiscountedCumulativeGain(
                shown,
                relevantProducts,
                candidateCount,
                topK);
            _returned += shown.Length;
            _totalHits += hits;
            if (shown.Length > 0)
                _usersWithRecommendations++;
            foreach (var productId in shown)
                _recommendedProducts.Add(productId);
        }

        public RecommendationEvaluationMethodResult ToResult(int users, int candidateProducts) => new(
            PrecisionAtK: _precision / users,
            RecallAtK: _recall / users,
            HitRateAtK: _hitRate / users,
            MeanReciprocalRankAtK: _mrr / users,
            NormalizedDiscountedCumulativeGainAtK: _ndcg / users,
            CatalogCoverageAtK: candidateProducts == 0 ? 0d : (double)_recommendedProducts.Count / candidateProducts,
            AverageRecommendationsReturned: _returned / users,
            TotalHits: _totalHits,
            UsersWithRecommendations: _usersWithRecommendations);

        private static double ReciprocalRank(
            IReadOnlyList<int> ranking,
            IReadOnlySet<int> relevantProducts)
        {
            for (var index = 0; index < ranking.Count; index++)
            {
                if (relevantProducts.Contains(ranking[index]))
                    return 1d / (index + 1);
            }

            return 0d;
        }

        private static double NormalizedDiscountedCumulativeGain(
            IReadOnlyList<int> ranking,
            IReadOnlySet<int> relevantProducts,
            int candidateCount,
            int topK)
        {
            var dcg = 0d;
            for (var index = 0; index < ranking.Count && index < topK; index++)
            {
                if (relevantProducts.Contains(ranking[index]))
                    dcg += 1d / Math.Log2(index + 2d);
            }

            var idealResultCount = Math.Min(
                relevantProducts.Count,
                Math.Min(topK, candidateCount));
            if (idealResultCount == 0)
                return 0d;

            var idealDcg = Enumerable.Range(0, idealResultCount)
                .Sum(index => 1d / Math.Log2(index + 2d));
            return dcg / idealDcg;
        }
    }
}

public sealed record TemporalPurchaseSignal(
    int UserId,
    int ProductId,
    int OrderId,
    int Quantity,
    DateTime PurchasedAt);

public sealed record RecommendationEvaluationMethodResult(
    double? PrecisionAtK,
    double? RecallAtK,
    double? HitRateAtK,
    double? MeanReciprocalRankAtK,
    double? NormalizedDiscountedCumulativeGainAtK,
    double? CatalogCoverageAtK,
    double? AverageRecommendationsReturned,
    int TotalHits,
    int UsersWithRecommendations);

public sealed record RecommendationEvaluationReport(
    bool IsAvailable,
    string? UnavailableReason,
    int CandidateProducts,
    int EvaluatedUsers,
    int ColdStartUsers,
    int UsersWithoutNovelHoldout,
    int ExcludedHoldoutProductsWithoutTrainingEvidence,
    RecommendationEvaluationMethodResult CollaborativeFiltering,
    RecommendationEvaluationMethodResult PopularityBaseline)
{
    public static RecommendationEvaluationReport Unavailable(
        string reason,
        int candidateProducts,
        int coldStartUsers = 0,
        int usersWithoutNovelHoldout = 0,
        int excludedHoldoutProductsWithoutTrainingEvidence = 0) => new(
        IsAvailable: false,
        UnavailableReason: reason,
        CandidateProducts: candidateProducts,
        EvaluatedUsers: 0,
        ColdStartUsers: coldStartUsers,
        UsersWithoutNovelHoldout: usersWithoutNovelHoldout,
        ExcludedHoldoutProductsWithoutTrainingEvidence: excludedHoldoutProductsWithoutTrainingEvidence,
        CollaborativeFiltering: EmptyMethodResult,
        PopularityBaseline: EmptyMethodResult);

    private static readonly RecommendationEvaluationMethodResult EmptyMethodResult = new(
        PrecisionAtK: null,
        RecallAtK: null,
        HitRateAtK: null,
        MeanReciprocalRankAtK: null,
        NormalizedDiscountedCumulativeGainAtK: null,
        CatalogCoverageAtK: null,
        AverageRecommendationsReturned: null,
        TotalHits: 0,
        UsersWithRecommendations: 0);
}
