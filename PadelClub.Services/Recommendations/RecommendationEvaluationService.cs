using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Services.Database;

namespace PadelClub.Services.Recommendations;

/// <summary>
/// Builds a leakage-aware historical recommendation backtest from explicitly
/// provenance-eligible delivered purchase data. The serving recommender can
/// retain demo history for an exam demonstration; this evaluator never can.
/// </summary>
public sealed class RecommendationEvaluationService : IRecommendationEvaluationService
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private static readonly OrderOrigin[] EligibleOrigins =
    [
        OrderOrigin.CustomerCheckout,
        OrderOrigin.VerifiedImport
    ];

    private readonly PadelClubContext _db;

    public RecommendationEvaluationService(PadelClubContext db)
    {
        _db = db;
    }

    public async Task<RecommendationEvaluationResponse> EvaluateAsync(
        RecommendationEvaluationRequest request,
        CancellationToken cancellationToken = default) =>
        (await EvaluateDetailedAsync(request, DateTime.UtcNow, cancellationToken)).Response;

    public async Task<RecommendationEvaluationRunResponse> CreateRunAsync(
        int executedByUserId,
        RecommendationEvaluationRequest request,
        CancellationToken cancellationToken = default)
    {
        if (executedByUserId <= 0)
            throw new ArgumentOutOfRangeException(nameof(executedByUserId));

        var executedAtUtc = DateTime.UtcNow;
        var computation = await EvaluateDetailedAsync(request, executedAtUtc, cancellationToken);
        var response = computation.Response;
        var run = new RecommendationEvaluationRun
        {
            RunId = Guid.NewGuid(),
            ExecutedByUserId = executedByUserId,
            ExecutedAtUtc = executedAtUtc,
            EvidenceSource = response.EvidenceSource,
            EvidenceTier = response.EvidenceTier,
            Protocol = response.Protocol,
            AlgorithmVersion = response.AlgorithmVersion,
            ConfigurationSha256 = response.ConfigurationSha256,
            InputFingerprintSha256 = response.InputFingerprintSha256,
            CutoffUtc = response.CutoffUtc.UtcDateTime,
            EndUtc = response.EndUtc.UtcDateTime,
            K = response.K,
            ReturnMaturityDays = RecommendationEvaluationQualityPolicy.MinimumReturnMaturityDays,
            EligibleDeliveredOrders = response.Cohort.DeliveredOrders,
            TrainingSignals = response.Cohort.TrainingSignals,
            HoldoutSignals = response.Cohort.HoldoutSignals,
            CandidateProducts = response.Cohort.CandidateProducts,
            EvaluatedUsers = response.Cohort.EvaluatedUsers,
            ReportJson = JsonSerializer.Serialize(response, JsonOptions)
        };

        _db.RecommendationEvaluationRuns.Add(run);
        await _db.SaveChangesAsync(cancellationToken);
        return ToRunResponse(run, response);
    }

    public async Task<RecommendationEvaluationRunResponse?> GetRunAsync(
        Guid runId,
        CancellationToken cancellationToken = default)
    {
        var run = await _db.RecommendationEvaluationRuns
            .AsNoTracking()
            .SingleOrDefaultAsync(item => item.RunId == runId, cancellationToken);
        return run is null ? null : ToRunResponse(run);
    }

    public async Task<RecommendationEvaluationRunResponse?> GetLatestRunAsync(
        CancellationToken cancellationToken = default)
    {
        var run = await _db.RecommendationEvaluationRuns
            .AsNoTracking()
            .OrderByDescending(item => item.ExecutedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
        return run is null ? null : ToRunResponse(run);
    }

    private async Task<EvaluationComputation> EvaluateDetailedAsync(
        RecommendationEvaluationRequest request,
        DateTime evaluatedAtUtc,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(request);
        if (request.CutoffUtc is null || request.EndUtc is null)
            throw new ArgumentException("CutoffUtc and EndUtc are required.", nameof(request));
        if (request.K is < 1 or > 12)
            throw new ArgumentOutOfRangeException(nameof(request.K), "K must be between 1 and 12.");

        var cutoff = request.CutoffUtc.Value.UtcDateTime;
        var end = request.EndUtc.Value.UtcDateTime;
        if (end <= cutoff)
            throw new ArgumentException("EndUtc must be after CutoffUtc.", nameof(request));

        // Deliberately start from all relevant delivered order lines so the
        // returned report can disclose what was excluded. Candidate evidence
        // is then selected fail-closed below.
        var sourceLines = await _db.OrderItems
            .AsNoTracking()
            .Where(item =>
                item.Order.Status == "Delivered" &&
                item.Order.User.IsActive &&
                item.Order.CreatedAt < end)
            .Select(item => new DeliveredOrderLine(
                item.Id,
                item.OrderId,
                item.Order.UserId,
                item.ProductId,
                item.Quantity,
                item.Order.DeliveredAt,
                item.Order.CreatedAt,
                item.Order.Origin,
                item.Order.IsSeededForDemo))
            .ToListAsync(cancellationToken);
        var returnAdjustments = await _db.ReturnRequestItems
            .AsNoTracking()
            .Where(item => item.ReturnRequest.Status == "Approved" || item.ReturnRequest.Status == "Refunded")
            .Select(item => new ReturnAdjustment(
                item.OrderItemId,
                item.Quantity,
                item.ReturnRequest.ResolvedAt))
            .ToListAsync(cancellationToken);

        var orderSources = sourceLines
            .GroupBy(line => line.OrderId)
            .Select(group => new OrderSource(
                group.Key,
                group.First().Origin,
                group.First().IsSeededForDemo,
                group.First().DeliveredAt,
                group.First().CreatedAt))
            .ToArray();
        var eligibleLines = sourceLines
            .Where(line => line.IsProvenanceEligible)
            .Where(line => line.DeliveredAt is not null && line.PurchasedAt < end)
            .ToArray();
        var eligibleLineIds = eligibleLines.Select(line => line.OrderItemId).ToHashSet();
        var unresolvedApprovedOrRefundedReturns = returnAdjustments
            .Count(adjustment =>
                eligibleLineIds.Contains(adjustment.OrderItemId) &&
                adjustment.ResolvedAt is null);

        var training = BuildNetSignals(
            eligibleLines,
            returnAdjustments,
            DateTime.MinValue,
            cutoff,
            cutoff);
        var holdout = BuildNetSignals(
            eligibleLines,
            returnAdjustments,
            cutoff,
            end,
            end.AddDays(RecommendationEvaluationQualityPolicy.MinimumReturnMaturityDays));
        var candidateProductIds = training
            .Select(signal => signal.ProductId)
            .Distinct()
            .ToArray();
        var report = TemporalRecommendationEvaluator.Evaluate(
            training,
            holdout,
            candidateProductIds,
            cutoff,
            request.K);

        var excludedSeededDemoOrders = orderSources.Count(order =>
            order.IsSeededForDemo || order.Origin == OrderOrigin.SeedDemo);
        var excludedUnverifiedLegacyOrders = orderSources.Count(order =>
            !order.IsSeededForDemo && order.Origin == OrderOrigin.UnverifiedLegacy);
        var excludedNonOperationalOrders = orderSources.Count(order =>
            !order.IsSeededForDemo &&
            order.Origin is OrderOrigin.IntegrationTest or OrderOrigin.AdminCreated);
        var excludedOrdersWithoutDeliveredAt = orderSources.Count(order =>
            IsEligibleOrigin(order.Origin) &&
            !order.IsSeededForDemo &&
            order.DeliveredAt is null);

        if (eligibleLines.Length == 0)
        {
            report = report with
            {
                UnavailableReason = BuildNoEligibleCohortReason(
                    excludedSeededDemoOrders,
                    excludedUnverifiedLegacyOrders,
                    excludedNonOperationalOrders,
                    excludedOrdersWithoutDeliveredAt)
            };
        }

        var cohort = new RecommendationEvaluationCohortResponse
        {
            DeliveredOrders = eligibleLines.Select(line => line.OrderId).Distinct().Count(),
            ExcludedSeededDemoOrders = excludedSeededDemoOrders,
            ExcludedUnverifiedLegacyOrders = excludedUnverifiedLegacyOrders,
            ExcludedNonOperationalOrders = excludedNonOperationalOrders,
            ExcludedOrdersWithoutDeliveredAt = excludedOrdersWithoutDeliveredAt,
            UnresolvedApprovedOrRefundedReturns = unresolvedApprovedOrRefundedReturns,
            DistinctCustomers = eligibleLines.Select(line => line.UserId).Distinct().Count(),
            TrainingOrders = eligibleLines
                .Where(line => line.PurchasedAt < cutoff)
                .Select(line => line.OrderId)
                .Distinct()
                .Count(),
            HoldoutOrders = eligibleLines
                .Where(line => line.PurchasedAt >= cutoff && line.PurchasedAt < end)
                .Select(line => line.OrderId)
                .Distinct()
                .Count(),
            TrainingSignals = training.Count,
            HoldoutSignals = holdout.Count,
            CandidateProducts = report.CandidateProducts,
            CandidateProductsWithAtLeastTwoDistinctBuyers = training
                .GroupBy(signal => signal.ProductId)
                .Count(group => group.Select(signal => signal.UserId).Distinct().Count() >= 2),
            HistoricalObservationDays = HistoricalObservationDays(training, cutoff),
            EligibleOrderOrigins = EligibleOrigins.Select(origin => origin.ToString()).ToList(),
            EvaluatedUsers = report.EvaluatedUsers,
            ColdStartUsers = report.ColdStartUsers,
            UsersWithoutNovelHoldout = report.UsersWithoutNovelHoldout,
            ExcludedHoldoutProductsWithoutTrainingEvidence =
                report.ExcludedHoldoutProductsWithoutTrainingEvidence,
            // This is intentionally always zero: prior code exposed a fallback
            // counter, but operational evidence no longer has one.
            LegacyDeliveryTimestampFallbacks = 0
        };
        var quality = RecommendationEvaluationQualityPolicy.Assess(
            new RecommendationEvaluationQualityInput(
                report.IsAvailable,
                eligibleLines.All(line => line.IsProvenanceEligible),
                cohort.ExcludedOrdersWithoutDeliveredAt,
                cohort.UnresolvedApprovedOrRefundedReturns,
                end - cutoff,
                end,
                ToUtc(evaluatedAtUtc),
                cohort.DeliveredOrders,
                cohort.DistinctCustomers,
                cohort.TrainingSignals,
                cohort.HoldoutSignals,
                cohort.CandidateProducts,
                cohort.CandidateProductsWithAtLeastTwoDistinctBuyers,
                cohort.EvaluatedUsers,
                cohort.HistoricalObservationDays));
        var inputFingerprint = ComputeInputFingerprint(
            eligibleLines,
            returnAdjustments,
            cutoff,
            end,
            request.K);
        var configurationFingerprint = ComputeConfigurationFingerprint(cutoff, end, request.K);

        var response = new RecommendationEvaluationResponse
        {
            EvidenceSource = "Operational",
            EvidenceTier = quality.EvidenceTier,
            InputFingerprintSha256 = inputFingerprint,
            ConfigurationSha256 = configurationFingerprint,
            IsAvailable = report.IsAvailable,
            IsSmallSample = report.EvaluatedUsers < 5,
            UnavailableReason = report.UnavailableReason,
            Protocol = TemporalRecommendationEvaluator.Protocol,
            AlgorithmVersion = ItemBasedCollaborativeRanker.Version,
            CutoffUtc = request.CutoffUtc.Value.ToUniversalTime(),
            EndUtc = request.EndUtc.Value.ToUniversalTime(),
            K = request.K,
            Cohort = cohort,
            Quality = new RecommendationEvaluationQualityResponse
            {
                PolicyVersion = RecommendationEvaluationQualityPolicy.Version,
                IsMeaningful = quality.IsMeaningful,
                EvidenceTier = quality.EvidenceTier,
                MinimumHistoricalWindowDays = RecommendationEvaluationQualityPolicy.MinimumHistoricalWindowDays,
                MinimumReturnMaturityDays = RecommendationEvaluationQualityPolicy.MinimumReturnMaturityDays,
                MinimumDeliveredOrders = RecommendationEvaluationQualityPolicy.MinimumDeliveredOrders,
                MinimumTrainingSignals = RecommendationEvaluationQualityPolicy.MinimumTrainingSignals,
                MinimumHoldoutSignals = RecommendationEvaluationQualityPolicy.MinimumHoldoutSignals,
                MinimumCandidateProducts = RecommendationEvaluationQualityPolicy.MinimumCandidateProducts,
                MinimumEvaluatedUsers = RecommendationEvaluationQualityPolicy.MinimumEvaluatedUsers,
                Gates = quality.Gates.ToList(),
                UnmetRequirements = quality.UnmetRequirements.ToList()
            },
            CollaborativeFiltering = ToResponse(
                "item-to-item collaborative filtering",
                report.CollaborativeFiltering),
            PopularityBaseline = ToResponse(
                "distinct-buyer popularity baseline",
                report.PopularityBaseline),
            Limitations =
            [
                "Only delivered orders from active users with CustomerCheckout or VerifiedImport provenance and a DeliveredAt timestamp are considered.",
                "Seeded demo, integration-test, administrator-created, and unverified legacy orders are disclosed but excluded; they cannot become operational quality evidence.",
                "Approved/refunded returns are netted only when ResolvedAt is present: before cutoff for training and through a 30-day maturity observation after the holdout end for labels.",
                "A calculable result is only a qualified operational evidence claim when every returned provenance and data-sufficiency gate passes. It is not customer conversion, satisfaction, or causal-impact evidence.",
                "The historical candidate catalog is limited to products with pre-cutoff purchase evidence. Current stock, active state, and product-state values are not replayed because historical state snapshots are unavailable.",
                "Metrics evaluate warm users with a new retained holdout product. They do not measure cold-start quality, business conversion, or causal impact."
            ]
        };

        return new EvaluationComputation(response);
    }

    private static IReadOnlyList<TemporalPurchaseSignal> BuildNetSignals(
        IReadOnlyList<DeliveredOrderLine> deliveredLines,
        IReadOnlyList<ReturnAdjustment> returnAdjustments,
        DateTime startInclusive,
        DateTime endExclusive,
        DateTime returnsObservedBefore)
    {
        var returnedQuantityByLine = returnAdjustments
            .Where(adjustment => adjustment.ResolvedAt is not null)
            .Where(adjustment => ToUtc(adjustment.ResolvedAt!.Value) < returnsObservedBefore)
            .GroupBy(adjustment => adjustment.OrderItemId)
            .ToDictionary(group => group.Key, group => group.Sum(adjustment => adjustment.Quantity));

        return deliveredLines
            .Where(line => line.PurchasedAt >= startInclusive && line.PurchasedAt < endExclusive)
            .Select(line => new
            {
                Line = line,
                NetQuantity = line.Quantity - returnedQuantityByLine.GetValueOrDefault(line.OrderItemId)
            })
            .Where(item => item.NetQuantity > 0)
            .Select(item => new TemporalPurchaseSignal(
                item.Line.UserId,
                item.Line.ProductId,
                item.Line.OrderId,
                item.NetQuantity,
                item.Line.PurchasedAt))
            .ToArray();
    }

    private static RecommendationEvaluationRunResponse ToRunResponse(
        RecommendationEvaluationRun run,
        RecommendationEvaluationResponse? knownReport = null)
    {
        var report = knownReport ?? JsonSerializer.Deserialize<RecommendationEvaluationResponse>(run.ReportJson, JsonOptions)
            ?? throw new InvalidOperationException("Persisted recommendation evaluation evidence is invalid.");
        return new RecommendationEvaluationRunResponse
        {
            RunId = run.RunId,
            ExecutedByUserId = run.ExecutedByUserId,
            ExecutedAtUtc = new DateTimeOffset(ToUtc(run.ExecutedAtUtc)),
            EvidenceSource = run.EvidenceSource,
            EvidenceTier = run.EvidenceTier,
            InputFingerprintSha256 = run.InputFingerprintSha256,
            ConfigurationSha256 = run.ConfigurationSha256,
            Report = report
        };
    }

    private static RecommendationEvaluationMethodMetricsResponse ToResponse(
        string method,
        RecommendationEvaluationMethodResult metrics) => new()
        {
            Method = method,
            PrecisionAtK = metrics.PrecisionAtK,
            RecallAtK = metrics.RecallAtK,
            HitRateAtK = metrics.HitRateAtK,
            MeanReciprocalRankAtK = metrics.MeanReciprocalRankAtK,
            NormalizedDiscountedCumulativeGainAtK = metrics.NormalizedDiscountedCumulativeGainAtK,
            CatalogCoverageAtK = metrics.CatalogCoverageAtK,
            AverageRecommendationsReturned = metrics.AverageRecommendationsReturned,
            TotalHits = metrics.TotalHits,
            UsersWithRecommendations = metrics.UsersWithRecommendations
        };

    private static string BuildNoEligibleCohortReason(
        int seededDemoOrders,
        int unverifiedLegacyOrders,
        int nonOperationalOrders,
        int ordersWithoutDeliveredAt)
    {
        var exclusions = new List<string>();
        if (seededDemoOrders > 0) exclusions.Add($"{seededDemoOrders} seeded demo");
        if (unverifiedLegacyOrders > 0) exclusions.Add($"{unverifiedLegacyOrders} unverified legacy");
        if (nonOperationalOrders > 0) exclusions.Add($"{nonOperationalOrders} test/admin");
        if (ordersWithoutDeliveredAt > 0) exclusions.Add($"{ordersWithoutDeliveredAt} missing delivery timestamp");
        var detail = exclusions.Count == 0 ? "No delivered order lines were found." : $"Excluded: {string.Join(", ", exclusions)} order(s).";
        return "No provenance-eligible delivered order cohort was found. Only CustomerCheckout or VerifiedImport orders with DeliveredAt may contribute to operational recommendation evidence. " + detail;
    }

    private static int HistoricalObservationDays(
        IReadOnlyList<TemporalPurchaseSignal> training,
        DateTime cutoff)
    {
        if (training.Count == 0)
            return 0;
        return Math.Max(0, (int)Math.Floor((cutoff - training.Min(signal => signal.PurchasedAt)).TotalDays));
    }

    private static string ComputeInputFingerprint(
        IReadOnlyCollection<DeliveredOrderLine> lines,
        IReadOnlyCollection<ReturnAdjustment> returns,
        DateTime cutoff,
        DateTime end,
        int k)
    {
        var lineIds = lines.Select(line => line.OrderItemId).ToHashSet();
        var relevantReturnHorizon = end.AddDays(RecommendationEvaluationQualityPolicy.MinimumReturnMaturityDays);
        var canonicalLines = lines
            .OrderBy(line => line.OrderId)
            .ThenBy(line => line.OrderItemId)
            .Select(line => string.Join('|',
                "line",
                line.OrderId,
                line.UserId,
                line.ProductId,
                line.Quantity,
                line.PurchasedAt.ToString("O"),
                line.Origin));
        var canonicalReturns = returns
            .Where(adjustment => lineIds.Contains(adjustment.OrderItemId))
            .Where(adjustment => adjustment.ResolvedAt is not null && ToUtc(adjustment.ResolvedAt.Value) < relevantReturnHorizon)
            .OrderBy(adjustment => adjustment.OrderItemId)
            .ThenBy(adjustment => adjustment.ResolvedAt)
            .Select(adjustment => string.Join('|',
                "return",
                adjustment.OrderItemId,
                adjustment.Quantity,
                ToUtc(adjustment.ResolvedAt!.Value).ToString("O")));
        var canonical = string.Join(
            '\n',
            new[]
            {
                "operational-input-v1",
                cutoff.ToString("O"),
                end.ToString("O"),
                k.ToString()
            }.Concat(canonicalLines).Concat(canonicalReturns));
        return Sha256(canonical);
    }

    private static string ComputeConfigurationFingerprint(DateTime cutoff, DateTime end, int k) =>
        Sha256(string.Join('|',
            "recommendation-evaluation-config-v1",
            TemporalRecommendationEvaluator.Protocol,
            ItemBasedCollaborativeRanker.Version,
            RecommendationEvaluationQualityPolicy.Version,
            RecommendationEvaluationQualityPolicy.MinimumReturnMaturityDays,
            cutoff.ToString("O"),
            end.ToString("O"),
            k));

    private static string Sha256(string value) => Convert.ToHexString(
        SHA256.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();

    private static bool IsEligibleOrigin(OrderOrigin origin) => EligibleOrigins.Contains(origin);

    private static DateTime ToUtc(DateTime value) =>
        value.Kind == DateTimeKind.Utc
            ? value
            : DateTime.SpecifyKind(value, DateTimeKind.Utc);

    private sealed record EvaluationComputation(RecommendationEvaluationResponse Response);

    private sealed record OrderSource(
        int OrderId,
        OrderOrigin Origin,
        bool IsSeededForDemo,
        DateTime? DeliveredAt,
        DateTime CreatedAt);

    private sealed record DeliveredOrderLine(
        int OrderItemId,
        int OrderId,
        int UserId,
        int ProductId,
        int Quantity,
        DateTime? DeliveredAt,
        DateTime CreatedAt,
        OrderOrigin Origin,
        bool IsSeededForDemo)
    {
        public DateTime PurchasedAt => DeliveredAt is { } deliveredAt
            ? ToUtc(deliveredAt)
            : throw new InvalidOperationException("Operational evidence cannot use an order without DeliveredAt.");

        public bool IsProvenanceEligible =>
            !IsSeededForDemo &&
            IsEligibleOrigin(Origin);
    }

    private sealed record ReturnAdjustment(
        int OrderItemId,
        int Quantity,
        DateTime? ResolvedAt);
}
