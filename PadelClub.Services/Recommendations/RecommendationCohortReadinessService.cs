using Microsoft.EntityFrameworkCore;
using PadelClub.Model.Responses;
using PadelClub.Services.Database;

namespace PadelClub.Services.Recommendations;

/// <summary>
/// Reports whether future genuine checkout history is being collected in a
/// form that can eventually be evaluated. This service never upgrades data,
/// backfills timestamps, or returns customer-level transactions.
/// </summary>
public sealed class RecommendationCohortReadinessService : IRecommendationCohortReadinessService
{
    private readonly PadelClubContext _db;

    public RecommendationCohortReadinessService(PadelClubContext db)
    {
        _db = db;
    }

    public async Task<RecommendationCohortReadinessResponse> GetReadinessAsync(
        CancellationToken cancellationToken = default)
    {
        var generatedAtUtc = DateTime.UtcNow;
        var returnMaturityBoundary = generatedAtUtc
            .AddDays(-RecommendationEvaluationQualityPolicy.MinimumReturnMaturityDays);

        // This query deliberately mirrors the evaluator's provenance and
        // active-user boundary. It does not include seed, legacy, test, or
        // administrator-created rows simply because they would improve a count.
        var operationalOrderQuery = _db.Orders
            .AsNoTracking()
            .Where(order =>
                order.User.IsActive &&
                !order.IsSeededForDemo &&
                (order.Origin == OrderOrigin.CustomerCheckout ||
                 order.Origin == OrderOrigin.VerifiedImport));
        var operationalOrders = await operationalOrderQuery
            .Select(order => new OperationalOrder(
                order.Id,
                order.UserId,
                order.Origin,
                order.Status,
                order.DeliveredAt))
            .ToListAsync(cancellationToken);

        var eligibleDeliveredOrders = operationalOrders
            .Where(order => order.Status == "Delivered" && order.DeliveredAt is not null)
            .ToArray();
        var eligibleLines = await _db.OrderItems
            .AsNoTracking()
            .Where(line =>
                line.Order.User.IsActive &&
                !line.Order.IsSeededForDemo &&
                (line.Order.Origin == OrderOrigin.CustomerCheckout ||
                 line.Order.Origin == OrderOrigin.VerifiedImport) &&
                line.Order.Status == "Delivered" &&
                line.Order.DeliveredAt != null)
            .Select(line => new OperationalOrderLine(
                line.Id,
                line.OrderId,
                line.Order.UserId,
                line.ProductId,
                line.Quantity))
            .ToArrayAsync(cancellationToken);

        var resolvedReturnQuantities = await _db.ReturnRequestItems
            .AsNoTracking()
            .Where(item =>
                item.OrderItem.Order.User.IsActive &&
                !item.OrderItem.Order.IsSeededForDemo &&
                (item.OrderItem.Order.Origin == OrderOrigin.CustomerCheckout ||
                 item.OrderItem.Order.Origin == OrderOrigin.VerifiedImport) &&
                item.OrderItem.Order.Status == "Delivered" &&
                item.OrderItem.Order.DeliveredAt != null &&
                (item.ReturnRequest.Status == "Approved" || item.ReturnRequest.Status == "Refunded") &&
                item.ReturnRequest.ResolvedAt != null)
            .GroupBy(item => item.OrderItemId)
            .Select(group => new { OrderItemId = group.Key, Quantity = group.Sum(item => item.Quantity) })
            .ToDictionaryAsync(item => item.OrderItemId, item => item.Quantity, cancellationToken);

        var retainedLines = eligibleLines
            .Where(line => line.Quantity - resolvedReturnQuantities.GetValueOrDefault(line.Id) > 0)
            .ToArray();
        var maturedOrderIds = eligibleDeliveredOrders
            .Where(order => ToUtc(order.DeliveredAt!.Value) <= returnMaturityBoundary)
            .Select(order => order.Id)
            .ToHashSet();
        var maturedRetainedLines = retainedLines
            .Where(line => maturedOrderIds.Contains(line.OrderId))
            .ToArray();

        var returnReadiness = await GetReturnReadinessAsync(cancellationToken);

        var excludedDeliveredOrders = await _db.Orders
            .AsNoTracking()
            .Where(order => order.User.IsActive && order.Status == "Delivered")
            .Select(order => new ExcludedOrder(order.Origin, order.IsSeededForDemo))
            .ToListAsync(cancellationToken);

        var counts = new RecommendationCohortReadinessCountsResponse
        {
            CustomerCheckoutOrders = operationalOrders.Count(order => order.Origin == OrderOrigin.CustomerCheckout),
            VerifiedImportOrders = operationalOrders.Count(order => order.Origin == OrderOrigin.VerifiedImport),
            EligibleDeliveredOrders = eligibleDeliveredOrders.Length,
            MaturedEligibleDeliveredOrders = maturedOrderIds.Count,
            EligibleRetainedPurchaseSignals = retainedLines.Length,
            MaturedEligibleRetainedPurchaseSignals = maturedRetainedLines.Length,
            EligibleDistinctCustomers = eligibleDeliveredOrders.Select(order => order.UserId).Distinct().Count(),
            EligibleDistinctProducts = retainedLines.Select(line => line.ProductId).Distinct().Count(),
            EligibleProductsWithAtLeastTwoDistinctBuyers = retainedLines
                .GroupBy(line => line.ProductId)
                .Count(group => group.Select(line => line.UserId).Distinct().Count() >= 2),
            OperationalOrdersAwaitingDelivery = operationalOrders.Count(order =>
                order.Status is not "Delivered" and not "Cancelled"),
            EligibleDeliveredOrdersMissingDeliveredAt = operationalOrders.Count(order =>
                order.Status == "Delivered" && order.DeliveredAt is null),
            OpenOperationalReturnRequests = returnReadiness.OpenRequests,
            ApprovedOrRefundedReturnsMissingResolvedAt = returnReadiness.MissingResolutionTimestampItems,
            ExcludedSeededDemoOrders = excludedDeliveredOrders.Count(order =>
                order.IsSeededForDemo || order.Origin == OrderOrigin.SeedDemo),
            ExcludedUnverifiedLegacyOrders = excludedDeliveredOrders.Count(order =>
                !order.IsSeededForDemo && order.Origin == OrderOrigin.UnverifiedLegacy),
            ExcludedNonOperationalOrders = excludedDeliveredOrders.Count(order =>
                !order.IsSeededForDemo &&
                order.Origin is OrderOrigin.IntegrationTest or OrderOrigin.AdminCreated)
        };

        var firstEligibleDelivery = eligibleDeliveredOrders
            .Select(order => ToUtc(order.DeliveredAt!.Value))
            .OrderBy(value => value)
            .Select(value => (DateTime?)value)
            .FirstOrDefault();
        var latestEligibleDelivery = eligibleDeliveredOrders
            .Select(order => ToUtc(order.DeliveredAt!.Value))
            .OrderByDescending(value => value)
            .Select(value => (DateTime?)value)
            .FirstOrDefault();
        DateTime? earliestTimeOnlyWindowValidation = firstEligibleDelivery is null
            ? null
            : firstEligibleDelivery.Value
                .AddDays(RecommendationEvaluationQualityPolicy.MinimumHistoricalObservationDays)
                .AddDays(RecommendationEvaluationQualityPolicy.MinimumHistoricalWindowDays)
                .AddDays(RecommendationEvaluationQualityPolicy.MinimumReturnMaturityDays);
        var hasTimeOnlyMatureWindow = earliestTimeOnlyWindowValidation is not null &&
            earliestTimeOnlyWindowValidation.Value <= generatedAtUtc;

        var requirements = BuildRequirements(counts, hasTimeOnlyMatureWindow);
        var isReadyForWindowValidation = requirements
            .Where(requirement => requirement.Status != "RequiresEvaluationWindow")
            .All(requirement => requirement.Status == "Met");
        var readinessState = DetermineReadinessState(counts, isReadyForWindowValidation);

        return new RecommendationCohortReadinessResponse
        {
            GeneratedAtUtc = new DateTimeOffset(generatedAtUtc),
            EvidenceSource = "Operational",
            ReadinessState = readinessState,
            IsReadyForWindowValidation = isReadyForWindowValidation,
            Summary = BuildSummary(readinessState, counts),
            FirstEligibleDeliveryUtc = ToDateTimeOffset(firstEligibleDelivery),
            LatestEligibleDeliveryUtc = ToDateTimeOffset(latestEligibleDelivery),
            LatestReturnMaturedEvaluationEndUtc = new DateTimeOffset(returnMaturityBoundary),
            EarliestTimeOnlyWindowValidationAtUtc = ToDateTimeOffset(earliestTimeOnlyWindowValidation),
            Cohort = counts,
            Requirements = requirements,
            NextActions = BuildNextActions(counts, hasTimeOnlyMatureWindow, isReadyForWindowValidation),
            Limitations =
            [
                "This is aggregate collection progress, not a recommendation-quality metric or a customer-impact result.",
                "Only the fixed temporal evaluator, run with an explicit matured cutoff and end, can assess training, holdout, warm-user, and metric gates for that window.",
                "Seeded demo, integration-test, administrator-created, and unverified legacy orders remain excluded even if they improve a count.",
                "This report never changes order provenance or backfills DeliveredAt/ResolvedAt values."
            ]
        };
    }

    private async Task<ReturnReadiness> GetReturnReadinessAsync(CancellationToken cancellationToken)
    {
        var openRequests = await _db.ReturnRequests
            .AsNoTracking()
            .CountAsync(request =>
                request.Order.User.IsActive &&
                !request.Order.IsSeededForDemo &&
                (request.Order.Origin == OrderOrigin.CustomerCheckout ||
                 request.Order.Origin == OrderOrigin.VerifiedImport) &&
                request.Order.Status == "Delivered" &&
                request.Order.DeliveredAt != null &&
                request.Status == "Requested", cancellationToken);
        var missingResolutionTimestampItems = await _db.ReturnRequestItems
            .AsNoTracking()
            .CountAsync(item =>
                item.OrderItem.Order.User.IsActive &&
                !item.OrderItem.Order.IsSeededForDemo &&
                (item.OrderItem.Order.Origin == OrderOrigin.CustomerCheckout ||
                 item.OrderItem.Order.Origin == OrderOrigin.VerifiedImport) &&
                item.OrderItem.Order.Status == "Delivered" &&
                item.OrderItem.Order.DeliveredAt != null &&
                (item.ReturnRequest.Status == "Approved" || item.ReturnRequest.Status == "Refunded") &&
                item.ReturnRequest.ResolvedAt == null,
                cancellationToken);
        return new ReturnReadiness(openRequests, missingResolutionTimestampItems);
    }

    private static List<RecommendationCohortReadinessRequirementResponse> BuildRequirements(
        RecommendationCohortReadinessCountsResponse counts,
        bool hasTimeOnlyMatureWindow)
    {
        var requirements = new List<RecommendationCohortReadinessRequirementResponse>();
        AddRequirement(
            requirements,
            "provenance-boundary",
            "Met",
            "CustomerCheckout / VerifiedImport only",
            "CustomerCheckout / VerifiedImport only",
            "The collection query excludes seed, test, administrator-created, and unverified legacy rows by design.");
        AddRequirement(
            requirements,
            "delivery-timestamps",
            counts.EligibleDeliveredOrdersMissingDeliveredAt == 0 ? "Met" : "Gap",
            counts.EligibleDeliveredOrdersMissingDeliveredAt.ToString(),
            "0 missing DeliveredAt",
            "A Delivered status cannot substitute for a true delivery time; CreatedAt is never a fallback.");
        AddRequirement(
            requirements,
            "return-resolution-timestamps",
            counts.ApprovedOrRefundedReturnsMissingResolvedAt == 0 ? "Met" : "Gap",
            counts.ApprovedOrRefundedReturnsMissingResolvedAt.ToString(),
            "0 missing ResolvedAt",
            "Approved/refunded return items require an actual outcome time before they can be netted safely.");
        AddRequirement(
            requirements,
            "eligible-delivered-orders-collection",
            counts.EligibleDeliveredOrders >= RecommendationEvaluationQualityPolicy.MinimumDeliveredOrders ? "Met" : "Gap",
            counts.EligibleDeliveredOrders.ToString(),
            $">= {RecommendationEvaluationQualityPolicy.MinimumDeliveredOrders} all-time delivered orders",
            "Collection progress only. The evaluator rechecks delivered orders inside the selected historical window.");
        AddRequirement(
            requirements,
            "distinct-customers-collection",
            counts.EligibleDistinctCustomers >= RecommendationEvaluationQualityPolicy.MinimumDistinctCustomers ? "Met" : "Gap",
            counts.EligibleDistinctCustomers.ToString(),
            $">= {RecommendationEvaluationQualityPolicy.MinimumDistinctCustomers} all-time customers",
            "Collection progress only. The final number is split-specific and uses the selected window.");
        AddRequirement(
            requirements,
            "candidate-products-collection",
            counts.EligibleDistinctProducts >= RecommendationEvaluationQualityPolicy.MinimumCandidateProducts ? "Met" : "Gap",
            counts.EligibleDistinctProducts.ToString(),
            $">= {RecommendationEvaluationQualityPolicy.MinimumCandidateProducts} all-time retained products",
            "Uses delivered lines after currently resolved approved/refunded returns are subtracted.");
        AddRequirement(
            requirements,
            "multi-buyer-candidates-collection",
            counts.EligibleProductsWithAtLeastTwoDistinctBuyers >= RecommendationEvaluationQualityPolicy.MinimumCandidateProductsWithTwoDistinctBuyers
                ? "Met"
                : "Gap",
            counts.EligibleProductsWithAtLeastTwoDistinctBuyers.ToString(),
            $">= {RecommendationEvaluationQualityPolicy.MinimumCandidateProductsWithTwoDistinctBuyers} products with two distinct buyers",
            "Collection progress only; this avoids treating a single repeat buyer as broad collaborative support.");
        AddRequirement(
            requirements,
            "calendar-maturity",
            hasTimeOnlyMatureWindow ? "Met" : "Gap",
            hasTimeOnlyMatureWindow ? "time-only window possible" : "not yet possible",
            $"{RecommendationEvaluationQualityPolicy.MinimumHistoricalObservationDays}-day pre-fold history + " +
            $"{RecommendationEvaluationQualityPolicy.MinimumHistoricalWindowDays}-day holdout + " +
            $"{RecommendationEvaluationQualityPolicy.MinimumReturnMaturityDays}-day return maturity",
            "Calendar coverage alone is insufficient: the selected window must still contain adequate retained signals.");
        AddRequirement(
            requirements,
            "split-specific-evidence",
            "RequiresEvaluationWindow",
            "not assessed by collection preflight",
            "explicit mature cutoff/end and evaluator result",
            "Training/holdout signals, warm evaluable users, metric availability, and the final evidence tier are intentionally assessed only by the temporal evaluator.");
        return requirements;
    }

    private static void AddRequirement(
        ICollection<RecommendationCohortReadinessRequirementResponse> requirements,
        string name,
        string status,
        string observed,
        string required,
        string detail) => requirements.Add(new RecommendationCohortReadinessRequirementResponse
        {
            Name = name,
            Status = status,
            Observed = observed,
            Required = required,
            Detail = detail
        });

    private static string DetermineReadinessState(
        RecommendationCohortReadinessCountsResponse counts,
        bool isReadyForWindowValidation)
    {
        if (counts.EligibleDeliveredOrdersMissingDeliveredAt > 0 ||
            counts.ApprovedOrRefundedReturnsMissingResolvedAt > 0)
            return "DataQualityBlocked";
        if (counts.EligibleDeliveredOrders == 0)
            return "NoEligibleCohort";
        return isReadyForWindowValidation ? "ReadyForWindowValidation" : "Collecting";
    }

    private static string BuildSummary(
        string readinessState,
        RecommendationCohortReadinessCountsResponse counts) => readinessState switch
    {
        "NoEligibleCohort" =>
            "No provenance-eligible delivered checkout/import orders are currently available. Demo, test, administrator-created, and legacy orders are not promoted into operational evidence.",
        "DataQualityBlocked" =>
            "Operational deliveries exist, but missing delivery or return-resolution timestamps block a reliable historical cohort. Do not infer missing timestamps from request or creation times.",
        "ReadyForWindowValidation" =>
            "Aggregate collection preflight has passed. Select an explicit mature historical window and run the evaluator; only that evaluation can produce a Diagnostic or Qualified evidence tier.",
        _ =>
            $"Operational history is being collected, but it has {counts.EligibleDeliveredOrders} eligible delivered order(s) and still needs more calendar coverage, diversity, or volume before a window should be validated."
    };

    private static List<string> BuildNextActions(
        RecommendationCohortReadinessCountsResponse counts,
        bool hasTimeOnlyMatureWindow,
        bool isReadyForWindowValidation)
    {
        var actions = new List<string>();
        if (counts.CustomerCheckoutOrders == 0)
            actions.Add("Collect authentic player purchases through the authenticated checkout flow; it assigns CustomerCheckout provenance server-side.");
        if (counts.OperationalOrdersAwaitingDelivery > 0)
            actions.Add($"Record real fulfilment outcomes for {counts.OperationalOrdersAwaitingDelivery} operational order(s) awaiting delivery. Move an order to Delivered only when it is actually delivered so DeliveredAt is trustworthy.");
        if (counts.EligibleDeliveredOrdersMissingDeliveredAt > 0)
            actions.Add("Verify missing delivery times from an authoritative fulfilment record or leave those orders excluded. Never backfill DeliveredAt from CreatedAt.");
        if (counts.ApprovedOrRefundedReturnsMissingResolvedAt > 0)
            actions.Add("Record an actual ResolvedAt time for approved/refunded return outcomes or leave the affected evidence blocked; never substitute the return-request time.");
        if (counts.OpenOperationalReturnRequests > 0)
            actions.Add($"Monitor {counts.OpenOperationalReturnRequests} open operational return request(s); a later approved/refunded outcome can change retained-purchase evidence.");
        AddCollectionGapAction(
            actions,
            counts.EligibleDeliveredOrders,
            RecommendationEvaluationQualityPolicy.MinimumDeliveredOrders,
            "more provenance-eligible delivered order(s)");
        AddCollectionGapAction(
            actions,
            counts.EligibleDistinctCustomers,
            RecommendationEvaluationQualityPolicy.MinimumDistinctCustomers,
            "more distinct operational customer(s)");
        AddCollectionGapAction(
            actions,
            counts.EligibleDistinctProducts,
            RecommendationEvaluationQualityPolicy.MinimumCandidateProducts,
            "more retained product(s) represented in operational purchases");
        AddCollectionGapAction(
            actions,
            counts.EligibleProductsWithAtLeastTwoDistinctBuyers,
            RecommendationEvaluationQualityPolicy.MinimumCandidateProductsWithTwoDistinctBuyers,
            "more product(s) with purchases from at least two distinct customers");
        if (!hasTimeOnlyMatureWindow && counts.EligibleDeliveredOrders > 0)
            actions.Add("Continue collecting timestamped delivered purchases until a potential split has 90 days of pre-fold history, a 28-day holdout, and a 30-day return-maturity buffer.");
        if (isReadyForWindowValidation)
            actions.Add("Choose an explicit UTC cutoff/end no more than 366 days apart, then run and optionally snapshot the temporal evaluator. Do not label this preflight itself as qualified evidence.");
        return actions;
    }

    private static void AddCollectionGapAction(
        ICollection<string> actions,
        int observed,
        int minimum,
        string noun)
    {
        var remaining = Math.Max(0, minimum - observed);
        if (remaining > 0)
            actions.Add($"Continue collecting at least {remaining} {noun} before treating aggregate collection thresholds as met. Split-specific evaluation gates still apply.");
    }

    private static DateTime ToUtc(DateTime value) => value.Kind == DateTimeKind.Utc
        ? value
        : DateTime.SpecifyKind(value, DateTimeKind.Utc);

    private static DateTimeOffset? ToDateTimeOffset(DateTime? value) => value is null
        ? null
        : new DateTimeOffset(ToUtc(value.Value));

    private sealed record OperationalOrder(
        int Id,
        int UserId,
        OrderOrigin Origin,
        string Status,
        DateTime? DeliveredAt);

    private sealed record OperationalOrderLine(
        int Id,
        int OrderId,
        int UserId,
        int ProductId,
        int Quantity);

    private sealed record ExcludedOrder(OrderOrigin Origin, bool IsSeededForDemo);

    private sealed record ReturnReadiness(int OpenRequests, int MissingResolutionTimestampItems);
}
