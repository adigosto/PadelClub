using Microsoft.EntityFrameworkCore;
using PadelClub.Model.Responses;
using PadelClub.Services.Database;

namespace PadelClub.Services.Recommendations;

public sealed class ProductRecommendationService : IProductRecommendationService
{
    private readonly PadelClubContext _db;
    private readonly IRecommendationTelemetryEnvironment? _telemetryEnvironment;
    private readonly IRecommendationExperimentService? _experiments;

    public ProductRecommendationService(PadelClubContext db)
    {
        _db = db;
    }

    public ProductRecommendationService(
        PadelClubContext db,
        IRecommendationTelemetryEnvironment telemetryEnvironment)
    {
        _db = db;
        _telemetryEnvironment = telemetryEnvironment;
    }

    public ProductRecommendationService(
        PadelClubContext db,
        IRecommendationTelemetryEnvironment telemetryEnvironment,
        IRecommendationExperimentService experiments)
    {
        _db = db;
        _telemetryEnvironment = telemetryEnvironment;
        _experiments = experiments;
    }

    public async Task<IReadOnlyList<ProductRecommendationResponse>> GetForUserAsync(
        int userId,
        int limit,
        CancellationToken cancellationToken = default)
    {
        var take = Math.Clamp(limit, 1, 12);
        var products = (await _db.Products
                .AsNoTracking()
                .Where(x => x.IsActive && x.StockQuantity > 0)
                .Select(x => new ProductSnapshot(
                    x.Id,
                    x.Name,
                    x.Description,
                    x.Price,
                    x.StockQuantity,
                    x.ImageUrl,
                    x.CreatedAt,
                    x.UpdatedAt,
                    x.ProductState))
                .ToListAsync(cancellationToken))
            .Where(x => !x.ProductState.Contains("deactivated", StringComparison.OrdinalIgnoreCase))
            .ToList();

        if (products.Count == 0)
            return Array.Empty<ProductRecommendationResponse>();

        // Telemetry source is determined only from server-side deployment and
        // account state. A client receives an opaque exposure ID but never
        // chooses whether that interaction may qualify as operational evidence.
        var telemetrySource = await ResolveTelemetrySourceAsync(userId, cancellationToken);
        // A nullable assignment means ordinary serving. Assignments exist only
        // for consented, production OperationalCustomer traffic and are never
        // returned to the client, which prevents a player from selecting an
        // experiment arm or turning local/demo traffic into evidence.
        var experimentAssignment = _experiments is null
            ? null
            : await _experiments.GetActiveAssignmentAsync(
                userId, telemetrySource, take, cancellationToken);

        // A Delivered order is the strongest existing purchase signal in this application.
        // Pending checkouts and rejected/returned merchandise must not teach the recommender.
        var rawPurchaseLines = await _db.OrderItems
            .AsNoTracking()
            .Where(x => x.Order.Status == "Delivered" && x.Order.User.IsActive &&
                !x.Order.IsSeededForDemo &&
                (x.Order.Origin == OrderOrigin.CustomerCheckout || x.Order.Origin == OrderOrigin.VerifiedImport))
            .Select(x => new
            {
                OrderItemId = x.Id,
                x.Order.UserId,
                x.ProductId,
                x.Product.Name,
                x.Quantity,
                PurchasedAt = x.Order.DeliveredAt ?? x.Order.CreatedAt
            })
            .ToListAsync(cancellationToken);

        var returnedLines = await _db.ReturnRequestItems
            .AsNoTracking()
            .Where(x => x.ReturnRequest.Status == "Approved" || x.ReturnRequest.Status == "Refunded")
            .Select(x => new { x.OrderItemId, x.Quantity })
            .ToListAsync(cancellationToken);
        var returnedQuantityByLine = returnedLines
            .GroupBy(x => x.OrderItemId)
            .ToDictionary(group => group.Key, group => group.Sum(x => x.Quantity));

        var purchaseSignals = rawPurchaseLines
            .Select(line => new
            {
                line.UserId,
                line.ProductId,
                line.Name,
                NetQuantity = line.Quantity - returnedQuantityByLine.GetValueOrDefault(line.OrderItemId),
                line.PurchasedAt
            })
            .Where(line => line.NetQuantity > 0)
            .Select(line => new PurchaseSignal(
                line.UserId,
                line.ProductId,
                line.NetQuantity,
                line.PurchasedAt))
            .ToList();

        var productNameById = rawPurchaseLines
            .GroupBy(x => x.ProductId)
            .ToDictionary(group => group.Key, group => group.First().Name);
        var productsById = products.ToDictionary(x => x.Id);
        var selectedProductIds = new HashSet<int>();
        var recommendations = new List<ProductRecommendationResponse>();

        if (experimentAssignment?.Variant == RecommendationExperimentVariant.Control)
        {
            // The control arm always receives the same deterministic
            // distinct-buyer popularity baseline. It is not the old
            // fallback-only path, so the experiment has a genuine arm-level
            // contrast rather than relabelling sparse CF results as control.
            var controlScores = PopularityRecommendationRanker.Rank(
                userId,
                purchaseSignals,
                products.Select(product => new RecommendationCandidate(product.Id)));
            foreach (var ranked in controlScores)
            {
                if (recommendations.Count >= take ||
                    !productsById.TryGetValue(ranked.ProductId, out var product))
                {
                    continue;
                }

                var isPopular = ranked.SupportingCustomers > 0;
                recommendations.Add(ToResponse(
                    product,
                    ranked.Score,
                    isPopular
                        ? "Popular with club shop customers."
                        : "New in the club shop.",
                    strategy: experimentAssignment.Strategy,
                    isFallback: false,
                    becauseProductName: null,
                    supportingCustomers: ranked.SupportingCustomers,
                    algorithmVersion: experimentAssignment.AlgorithmVersion));
            }

            return await RecordExposuresAsync(
                userId,
                recommendations,
                telemetrySource,
                experimentAssignment,
                cancellationToken);
        }

        var collaborativeScores = ItemBasedCollaborativeRanker.Rank(
            userId,
            purchaseSignals,
            products.Select(x => new RecommendationCandidate(x.Id)),
            DateTime.UtcNow);

        foreach (var ranked in collaborativeScores)
        {
            if (recommendations.Count >= take || !productsById.TryGetValue(ranked.ProductId, out var product))
                continue;

            selectedProductIds.Add(product.Id);
            productNameById.TryGetValue(ranked.BecauseProductId, out var sourceProductName);
            recommendations.Add(ToResponse(
                product,
                ranked.Score,
                string.IsNullOrWhiteSpace(sourceProductName)
                    ? "Based on similar completed purchases from other players."
                    : $"Players who bought {sourceProductName} also bought this item.",
                strategy: "collaborative-filtering",
                isFallback: false,
                becauseProductName: sourceProductName,
                supportingCustomers: ranked.SupportingCustomers,
                algorithmVersion: experimentAssignment?.AlgorithmVersion ?? ItemBasedCollaborativeRanker.Version));
        }

        if (recommendations.Count >= take)
            return await RecordExposuresAsync(
                userId,
                recommendations,
                telemetrySource,
                experimentAssignment,
                cancellationToken);

        var ownedProductIds = purchaseSignals
            .Where(x => x.UserId == userId)
            .Select(x => x.ProductId)
            .ToHashSet();
        var buyerCountByProduct = purchaseSignals
            .GroupBy(x => x.ProductId)
            .ToDictionary(group => group.Key, group => group.Select(x => x.UserId).Distinct().Count());
        var highestBuyerCount = buyerCountByProduct.Values.DefaultIfEmpty(0).Max();

        foreach (var product in products
                     .Where(x => !ownedProductIds.Contains(x.Id) && !selectedProductIds.Contains(x.Id))
                     .OrderByDescending(x => buyerCountByProduct.GetValueOrDefault(x.Id))
                     .ThenByDescending(x => x.CreatedAt)
                     .ThenBy(x => x.Name, StringComparer.Ordinal)
                     .ThenBy(x => x.Id))
        {
            if (recommendations.Count >= take)
                break;

            var buyerCount = buyerCountByProduct.GetValueOrDefault(product.Id);
            var isPopular = buyerCount > 0;
            recommendations.Add(ToResponse(
                product,
                highestBuyerCount == 0 ? 0d : (double)buyerCount / highestBuyerCount,
                isPopular ? "Popular with club shop customers." : "New in the club shop.",
                strategy: isPopular ? "popular-fallback" : "new-arrivals-fallback",
                isFallback: true,
                becauseProductName: null,
                supportingCustomers: buyerCount,
                algorithmVersion: experimentAssignment?.AlgorithmVersion ?? ItemBasedCollaborativeRanker.Version));
        }

        return await RecordExposuresAsync(
            userId,
            recommendations,
            telemetrySource,
            experimentAssignment,
            cancellationToken);
    }

    public async Task<bool> RecordClickAsync(
        int userId,
        Guid exposureId,
        CancellationToken cancellationToken = default)
    {
        var exposure = await _db.RecommendationExposures
            .SingleOrDefaultAsync(item => item.Id == exposureId && item.UserId == userId, cancellationToken);
        if (exposure is null)
            return false;

        // A repeat of a previously accepted click remains idempotent, but an
        // expired exposure can never be stamped later and rewrite its old CTR.
        if (exposure.ClickedAtUtc is not null)
            return RecommendationImpactPolicy.HasValidClickTiming(
                exposure.ServedAtUtc,
                exposure.ClickedAtUtc);

        var now = DateTime.UtcNow;
        if (!RecommendationImpactPolicy.CanRecordClick(exposure.ServedAtUtc, now))
            return false;

        exposure.ClickedAtUtc = now;
        await _db.SaveChangesAsync(cancellationToken);

        return true;
    }

    public async Task RecordCheckoutAttributionsAsync(
        int userId,
        int orderId,
        IReadOnlyCollection<RecommendationCheckoutAttribution> attributions,
        CancellationToken cancellationToken = default)
    {
        if (attributions.Count == 0)
            return;

        var claimedProductsByExposure = attributions
            .GroupBy(item => item.ExposureId)
            .ToDictionary(group => group.Key, group => group.Select(item => item.ProductId).Distinct().ToArray());
        var now = DateTime.UtcNow;
        var earliestAllowed = now.AddDays(-RecommendationImpactPolicy.AttributionWindowDays);
        var exposures = await _db.RecommendationExposures
            .Where(item =>
                item.UserId == userId &&
                item.PurchasedOrderId == null &&
                item.TelemetrySource == RecommendationTelemetrySource.OperationalCustomer &&
                item.ClickedAtUtc != null &&
                item.ServedAtUtc >= earliestAllowed &&
                claimedProductsByExposure.Keys.Contains(item.Id))
            .ToListAsync(cancellationToken);

        foreach (var exposure in exposures)
        {
            // A client can submit arbitrary GUIDs; only a single, matching
            // product exposure owned by this player is valid evidence.
            if (!claimedProductsByExposure.TryGetValue(exposure.Id, out var productIds) ||
                productIds.Length != 1 ||
                productIds[0] != exposure.ProductId ||
                !RecommendationImpactPolicy.HasValidAttributionTiming(
                    exposure.ServedAtUtc,
                    exposure.ClickedAtUtc,
                    now))
            {
                continue;
            }

            exposure.PurchasedOrderId = orderId;
            exposure.PurchasedAtUtc = now;
        }
    }

    private async Task<IReadOnlyList<ProductRecommendationResponse>> RecordExposuresAsync(
        int userId,
        IReadOnlyList<ProductRecommendationResponse> recommendations,
        RecommendationTelemetrySource telemetrySource,
        RecommendationExperimentAssignmentContext? experimentAssignment,
        CancellationToken cancellationToken)
    {
        if (recommendations.Count == 0)
            return recommendations;

        var servedAtUtc = DateTime.UtcNow;
        var exposures = recommendations
            .Select((recommendation, index) => new RecommendationExposure
            {
                UserId = userId,
                ProductId = recommendation.Product.Id,
                AlgorithmVersion = recommendation.AlgorithmVersion,
                Strategy = recommendation.Strategy,
                Rank = index + 1,
                ServedAtUtc = servedAtUtc,
                TelemetrySource = telemetrySource,
                ExperimentAssignmentId = experimentAssignment?.AssignmentId
            })
            .ToArray();
        _db.RecommendationExposures.AddRange(exposures);
        await _db.SaveChangesAsync(cancellationToken);

        return recommendations
            .Zip(exposures, (recommendation, exposure) => new ProductRecommendationResponse
            {
                ExposureId = exposure.Id,
                Product = recommendation.Product,
                Score = recommendation.Score,
                Reason = recommendation.Reason,
                Strategy = recommendation.Strategy,
                IsFallback = recommendation.IsFallback,
                AlgorithmVersion = recommendation.AlgorithmVersion,
                BecauseProductName = recommendation.BecauseProductName,
                SupportingCustomers = recommendation.SupportingCustomers
            })
            .ToArray();
    }

    private async Task<RecommendationTelemetrySource> ResolveTelemetrySourceAsync(
        int userId,
        CancellationToken cancellationToken)
    {
        var account = await _db.Users
            .AsNoTracking()
            .Where(user => user.Id == userId)
            .Select(user => new TelemetryAccount(
                user.IsActive,
                user.EmailVerifiedAt != null,
                user.UserRoles.Any(assignment =>
                    assignment.Role.IsActive && assignment.Role.Name == "Administrator"),
                user.UserRoles.Any(assignment =>
                    assignment.Role.IsActive && assignment.Role.Name == "Player"),
                user.Orders.Any(order =>
                    !order.IsSeededForDemo &&
                    (order.Origin == OrderOrigin.CustomerCheckout ||
                     order.Origin == OrderOrigin.VerifiedImport))))
            .SingleOrDefaultAsync(cancellationToken);

        if (account is null || !account.IsActive)
            return RecommendationTelemetrySource.Unverified;
        if (account.IsAdministrator)
            return RecommendationTelemetrySource.Administrator;

        // A Web host supplies this dependency. The parameterless test-only
        // constructor deliberately yields Unverified rather than assuming an
        // ad-hoc in-memory account represents production traffic.
        var environmentName = _telemetryEnvironment?.EnvironmentName;
        if (string.IsNullOrWhiteSpace(environmentName))
            return RecommendationTelemetrySource.Unverified;
        if (string.Equals(environmentName, "IntegrationTesting", StringComparison.OrdinalIgnoreCase))
            return RecommendationTelemetrySource.IntegrationTest;
        if (string.Equals(environmentName, "Development", StringComparison.OrdinalIgnoreCase))
            return RecommendationTelemetrySource.DevelopmentDemo;
        if (!string.Equals(environmentName, "Production", StringComparison.OrdinalIgnoreCase))
            return RecommendationTelemetrySource.NonProduction;

        return account.IsEmailVerified && account.IsPlayer && account.HasOperationalCommerceHistory
            ? RecommendationTelemetrySource.OperationalCustomer
            : RecommendationTelemetrySource.UnverifiedAccount;
    }

    private static ProductRecommendationResponse ToResponse(
        ProductSnapshot product,
        double score,
        string reason,
        string strategy,
        bool isFallback,
        string? becauseProductName,
        int supportingCustomers,
        string algorithmVersion) => new()
        {
            Product = new ProductResponse
            {
                Id = product.Id,
                Name = product.Name,
                Description = product.Description,
                Price = product.Price,
                StockQuantity = product.StockQuantity,
                ImageUrl = product.ImageUrl,
                CreatedAt = product.CreatedAt,
                UpdatedAt = product.UpdatedAt,
                ProductState = product.ProductState
            },
            Score = score,
            Reason = reason,
            Strategy = strategy,
            IsFallback = isFallback,
            AlgorithmVersion = algorithmVersion,
            BecauseProductName = becauseProductName,
            SupportingCustomers = supportingCustomers
        };

    private sealed record ProductSnapshot(
        int Id,
        string Name,
        string Description,
        decimal Price,
        int StockQuantity,
        string? ImageUrl,
        DateTime CreatedAt,
        DateTime? UpdatedAt,
        string ProductState);

    private sealed record TelemetryAccount(
        bool IsActive,
        bool IsEmailVerified,
        bool IsAdministrator,
        bool IsPlayer,
        bool HasOperationalCommerceHistory);
}
