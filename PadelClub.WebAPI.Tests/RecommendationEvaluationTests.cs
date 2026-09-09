using Microsoft.EntityFrameworkCore;
using PadelClub.Model.Requests;
using PadelClub.Services.Database;
using PadelClub.Services.Recommendations;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public class RecommendationEvaluationTests
{
    private static readonly DateTime Cutoff = new(2026, 8, 10, 0, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void Collaborative_filter_beats_distinct_buyer_popularity_on_a_fixed_temporal_fixture()
    {
        var training = new[]
        {
            Signal(1, 10, 1, Cutoff.AddDays(-6)),
            Signal(2, 10, 2, Cutoff.AddDays(-5)), Signal(2, 30, 2, Cutoff.AddDays(-5)),
            Signal(3, 10, 3, Cutoff.AddDays(-4)), Signal(3, 30, 3, Cutoff.AddDays(-4)),
            Signal(4, 20, 4, Cutoff.AddDays(-3)),
            Signal(5, 20, 5, Cutoff.AddDays(-2)),
            Signal(6, 20, 6, Cutoff.AddDays(-1))
        };
        var holdout = new[] { Signal(1, 30, 7, Cutoff.AddDays(1)) };

        var report = TemporalRecommendationEvaluator.Evaluate(
            training,
            holdout,
            candidateProductIds: [10, 20, 30],
            cutoffUtc: Cutoff,
            topK: 1);

        Assert.True(report.IsAvailable);
        Assert.Equal(1, report.EvaluatedUsers);
        Assert.Equal(1d, report.CollaborativeFiltering.PrecisionAtK!.Value, 10);
        Assert.Equal(1d, report.CollaborativeFiltering.RecallAtK!.Value, 10);
        Assert.Equal(1d, report.CollaborativeFiltering.HitRateAtK!.Value, 10);
        Assert.Equal(1d, report.CollaborativeFiltering.MeanReciprocalRankAtK!.Value, 10);
        Assert.Equal(
            1d,
            report.CollaborativeFiltering.NormalizedDiscountedCumulativeGainAtK!.Value,
            10);
        Assert.Equal(0d, report.PopularityBaseline.PrecisionAtK!.Value, 10);
        Assert.Equal(0d, report.PopularityBaseline.RecallAtK!.Value, 10);
        Assert.Equal(0d, report.PopularityBaseline.HitRateAtK!.Value, 10);
        Assert.Equal(
            0d,
            report.PopularityBaseline.NormalizedDiscountedCumulativeGainAtK!.Value,
            10);
    }

    [Fact]
    public void Evaluator_cannot_use_peer_purchases_after_the_cutoff()
    {
        var training = new[]
        {
            Signal(1, 10, 1, Cutoff.AddDays(-2)),
            Signal(2, 10, 2, Cutoff.AddDays(-1)), Signal(2, 30, 2, Cutoff.AddDays(-1))
        };
        var holdout = new[]
        {
            Signal(1, 30, 3, Cutoff.AddDays(1)),
            Signal(3, 10, 4, Cutoff.AddDays(1)), Signal(3, 20, 4, Cutoff.AddDays(1)),
            Signal(4, 10, 5, Cutoff.AddDays(2)), Signal(4, 20, 5, Cutoff.AddDays(2))
        };

        var report = TemporalRecommendationEvaluator.Evaluate(
            training,
            holdout,
            candidateProductIds: [10, 20, 30],
            cutoffUtc: Cutoff,
            topK: 1);

        Assert.True(report.IsAvailable);
        Assert.Equal(1d, report.CollaborativeFiltering.PrecisionAtK!.Value, 10);
        Assert.Equal(1d, report.CollaborativeFiltering.RecallAtK!.Value, 10);
    }

    [Fact]
    public void Sparse_window_returns_explicit_unavailability_instead_of_fake_zero_metrics()
    {
        var report = TemporalRecommendationEvaluator.Evaluate(
            [Signal(1, 10, 1, Cutoff.AddDays(-1))],
            Array.Empty<TemporalPurchaseSignal>(),
            candidateProductIds: [10],
            cutoffUtc: Cutoff,
            topK: 3);

        Assert.False(report.IsAvailable);
        Assert.NotNull(report.UnavailableReason);
        Assert.Null(report.CollaborativeFiltering.PrecisionAtK);
        Assert.Null(report.CollaborativeFiltering.NormalizedDiscountedCumulativeGainAtK);
        Assert.Null(report.PopularityBaseline.RecallAtK);
    }

    [Fact]
    public void Quality_policy_distinguishes_a_diagnostic_from_a_meaningful_cohort()
    {
        var meaningful = RecommendationEvaluationQualityPolicy.Assess(
            new RecommendationEvaluationQualityInput(
                IsAvailable: true,
                OnlyEligibleOriginsContributed: true,
                EligibleOrdersWithoutDeliveredAt: 0,
                UnresolvedApprovedOrRefundedReturns: 0,
                HistoricalWindow: TimeSpan.FromDays(28),
                EndUtc: Cutoff.AddDays(28),
                EvaluatedAtUtc: Cutoff.AddDays(58),
                DeliveredOrders: RecommendationEvaluationQualityPolicy.MinimumDeliveredOrders,
                DistinctCustomers: RecommendationEvaluationQualityPolicy.MinimumDistinctCustomers,
                TrainingSignals: RecommendationEvaluationQualityPolicy.MinimumTrainingSignals,
                HoldoutSignals: RecommendationEvaluationQualityPolicy.MinimumHoldoutSignals,
                CandidateProducts: RecommendationEvaluationQualityPolicy.MinimumCandidateProducts,
                CandidateProductsWithAtLeastTwoDistinctBuyers: RecommendationEvaluationQualityPolicy.MinimumCandidateProductsWithTwoDistinctBuyers,
                EvaluatedUsers: RecommendationEvaluationQualityPolicy.MinimumEvaluatedUsers,
                HistoricalObservationDays: RecommendationEvaluationQualityPolicy.MinimumHistoricalObservationDays));
        var diagnostic = RecommendationEvaluationQualityPolicy.Assess(
            new RecommendationEvaluationQualityInput(
                IsAvailable: true,
                OnlyEligibleOriginsContributed: true,
                EligibleOrdersWithoutDeliveredAt: 0,
                UnresolvedApprovedOrRefundedReturns: 0,
                HistoricalWindow: TimeSpan.FromDays(7),
                EndUtc: Cutoff.AddDays(7),
                EvaluatedAtUtc: Cutoff.AddDays(7),
                DeliveredOrders: 4,
                DistinctCustomers: 2,
                TrainingSignals: 5,
                HoldoutSignals: 2,
                CandidateProducts: 3,
                CandidateProductsWithAtLeastTwoDistinctBuyers: 0,
                EvaluatedUsers: 2,
                HistoricalObservationDays: 7));

        Assert.True(meaningful.IsMeaningful);
        Assert.Empty(meaningful.UnmetRequirements);
        Assert.False(diagnostic.IsMeaningful);
        Assert.Contains(
            diagnostic.UnmetRequirements,
            requirement => requirement.Contains("28 days", StringComparison.Ordinal));
        Assert.Contains(
            diagnostic.UnmetRequirements,
            requirement => requirement.Contains("warm-evaluable-users", StringComparison.Ordinal));
        Assert.Contains(
            diagnostic.UnmetRequirements,
            requirement => requirement.Contains("return-maturity", StringComparison.Ordinal));
    }

    [Fact]
    public async Task Return_outcomes_are_snapshotted_at_the_cutoff_and_end_of_the_window()
    {
        var options = new DbContextOptionsBuilder<PadelClubContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;
        await using var db = new PadelClubContext(options);

        var user = User(1, "evaluation-player");
        var productA = Product(10, "Returned before cutoff");
        var productB = Product(20, "Returned after cutoff");
        var productC = Product(30, "Returned in holdout");
        db.Users.Add(user);
        db.Products.AddRange(productA, productB, productC);

        var beforeCutoffReturned = Order(100, user, Cutoff.AddDays(-5));
        var afterCutoffReturned = Order(200, user, Cutoff.AddDays(-4));
        var holdoutReturned = Order(300, user, Cutoff.AddDays(2));
        var lineA = OrderItem(1000, beforeCutoffReturned, productA);
        var lineB = OrderItem(2000, afterCutoffReturned, productB);
        var lineC = OrderItem(3000, holdoutReturned, productC);
        db.Orders.AddRange(beforeCutoffReturned, afterCutoffReturned, holdoutReturned);
        db.OrderItems.AddRange(lineA, lineB, lineC);
        db.ReturnRequests.AddRange(
            Return(400, beforeCutoffReturned, user, Cutoff.AddDays(-2), lineA),
            Return(500, afterCutoffReturned, user, Cutoff.AddDays(3), lineB),
            // This return settles after the selected holdout end but within the
            // configured 30-day maturity period, so it must not remain a label.
            Return(600, holdoutReturned, user, Cutoff.AddDays(10), lineC));
        await db.SaveChangesAsync();

        var response = await new RecommendationEvaluationService(db).EvaluateAsync(
            new RecommendationEvaluationRequest
            {
                CutoffUtc = new DateTimeOffset(Cutoff),
                EndUtc = new DateTimeOffset(Cutoff.AddDays(7)),
                K = 3
            });

        Assert.Equal(1, response.Cohort.TrainingSignals);
        Assert.Equal(0, response.Cohort.HoldoutSignals);
        Assert.Equal(1, response.Cohort.CandidateProducts);
        Assert.False(response.IsAvailable);
        Assert.Equal(0, response.Cohort.LegacyDeliveryTimestampFallbacks);
    }

    [Fact]
    public async Task Seeded_demo_orders_are_excluded_from_historical_evaluation()
    {
        var options = new DbContextOptionsBuilder<PadelClubContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;
        await using var db = new PadelClubContext(options);

        var user = User(1, "demo-only-player");
        var racket = Product(10, "Demo racket");
        var balls = Product(20, "Demo balls");
        var trainingOrder = Order(100, user, Cutoff.AddDays(-2));
        var holdoutOrder = Order(200, user, Cutoff.AddDays(1));
        var futureDemoOrder = Order(300, user, Cutoff.AddDays(8));
        trainingOrder.IsSeededForDemo = true;
        holdoutOrder.IsSeededForDemo = true;
        futureDemoOrder.IsSeededForDemo = true;
        trainingOrder.Origin = OrderOrigin.SeedDemo;
        holdoutOrder.Origin = OrderOrigin.SeedDemo;
        futureDemoOrder.Origin = OrderOrigin.SeedDemo;
        db.Users.Add(user);
        db.Products.AddRange(racket, balls);
        db.Orders.AddRange(trainingOrder, holdoutOrder, futureDemoOrder);
        db.OrderItems.AddRange(
            OrderItem(1000, trainingOrder, racket),
            OrderItem(2000, holdoutOrder, balls),
            OrderItem(3000, futureDemoOrder, racket));
        await db.SaveChangesAsync();

        var response = await new RecommendationEvaluationService(db).EvaluateAsync(
            new RecommendationEvaluationRequest
            {
                CutoffUtc = new DateTimeOffset(Cutoff),
                EndUtc = new DateTimeOffset(Cutoff.AddDays(7)),
                K = 3
            });

        Assert.False(response.IsAvailable);
        Assert.Equal(0, response.Cohort.DeliveredOrders);
        // The seeded order after EndUtc is outside the evaluator's input window.
        Assert.Equal(2, response.Cohort.ExcludedSeededDemoOrders);
        Assert.Equal(0, response.Cohort.TrainingSignals);
        Assert.Equal(0, response.Cohort.HoldoutSignals);
        Assert.Contains("No provenance-eligible delivered order cohort", response.UnavailableReason);
        Assert.Null(response.CollaborativeFiltering.PrecisionAtK);
        Assert.Null(response.PopularityBaseline.PrecisionAtK);
    }

    [Fact]
    public async Task Historical_evaluation_uses_operational_orders_while_reporting_excluded_demo_orders()
    {
        var options = new DbContextOptionsBuilder<PadelClubContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;
        await using var db = new PadelClubContext(options);

        var player = User(1, "operational-player");
        var peer = User(2, "operational-peer");
        var racket = Product(10, "Operational racket");
        var balls = Product(20, "Operational balls");
        var excludedShoes = Product(30, "Demo shoes");
        var playerTraining = Order(100, player, Cutoff.AddDays(-5));
        var peerTraining = Order(200, peer, Cutoff.AddDays(-4));
        var playerHoldout = Order(300, player, Cutoff.AddDays(1));
        var demoOrder = Order(400, player, Cutoff.AddDays(-3));
        var futureLegacyOrder = Order(500, player, Cutoff.AddDays(10));
        var futureLegacyLine = OrderItem(5000, futureLegacyOrder, balls);
        futureLegacyOrder.DeliveredAt = null;
        demoOrder.IsSeededForDemo = true;
        demoOrder.Origin = OrderOrigin.SeedDemo;
        db.Users.AddRange(player, peer);
        db.Products.AddRange(racket, balls, excludedShoes);
        db.Orders.AddRange(
            playerTraining,
            peerTraining,
            playerHoldout,
            demoOrder,
            futureLegacyOrder);
        db.OrderItems.AddRange(
            OrderItem(1000, playerTraining, racket),
            OrderItem(2000, peerTraining, racket),
            OrderItem(2001, peerTraining, balls),
            OrderItem(3000, playerHoldout, balls),
            OrderItem(4000, demoOrder, excludedShoes),
            futureLegacyLine);
        await db.SaveChangesAsync();

        var response = await new RecommendationEvaluationService(db).EvaluateAsync(
            new RecommendationEvaluationRequest
            {
                CutoffUtc = new DateTimeOffset(Cutoff),
                EndUtc = new DateTimeOffset(Cutoff.AddDays(7)),
                K = 1
            });

        Assert.True(response.IsAvailable);
        Assert.Equal(3, response.Cohort.DeliveredOrders);
        Assert.Equal(1, response.Cohort.ExcludedSeededDemoOrders);
        Assert.Equal(2, response.Cohort.TrainingOrders);
        Assert.Equal(1, response.Cohort.HoldoutOrders);
        Assert.Equal(2, response.Cohort.CandidateProducts);
        Assert.Equal(0, response.Cohort.LegacyDeliveryTimestampFallbacks);
        Assert.False(response.Quality.IsMeaningful);
        Assert.NotNull(response.CollaborativeFiltering.PrecisionAtK);
        Assert.Contains(
            response.Limitations,
            limitation => limitation.Contains("Seeded demo", StringComparison.OrdinalIgnoreCase));
    }

    private static TemporalPurchaseSignal Signal(
        int userId,
        int productId,
        int orderId,
        DateTime purchasedAt) => new(userId, productId, orderId, 1, purchasedAt);

    private static User User(int id, string username) => new()
    {
        Id = id,
        Username = username,
        Email = $"{username}@example.test",
        FirstName = "Evaluation",
        LastName = "Player",
        PasswordHash = "test-hash",
        PasswordSalt = "test-salt",
        IsActive = true
    };

    private static Product Product(int id, string name) => new()
    {
        Id = id,
        Name = name,
        Description = name,
        Price = 10m,
        StockQuantity = 10,
        ProductCategoryId = 1,
        ProductTypeId = 1,
        ProductState = "ActiveProductState",
        IsActive = true
    };

    private static Order Order(int id, User user, DateTime deliveredAt) => new()
    {
        Id = id,
        UserId = user.Id,
        User = user,
        OrderNumber = $"EVAL-{id}",
        Status = "Delivered",
        DeliveredAt = deliveredAt,
        CreatedAt = deliveredAt,
        TotalAmount = 10m,
        RecipientName = "Evaluation Player",
        PhoneNumber = "000000000",
        ShippingAddress = "Test street 1",
        City = "Sarajevo",
        PostalCode = "71000",
        Origin = OrderOrigin.CustomerCheckout
    };

    private static OrderItem OrderItem(int id, Order order, Product product) => new()
    {
        Id = id,
        OrderId = order.Id,
        Order = order,
        ProductId = product.Id,
        Product = product,
        Quantity = 1,
        UnitPrice = 10m,
        TotalPrice = 10m,
        CreatedAt = order.DeliveredAt!.Value
    };

    private static ReturnRequest Return(
        int id,
        Order order,
        User user,
        DateTime resolvedAt,
        OrderItem line)
    {
        var request = new ReturnRequest
        {
            Id = id,
            OrderId = order.Id,
            Order = order,
            UserId = user.Id,
            Status = "Approved",
            Reason = "Evaluation return",
            CreatedAt = resolvedAt.AddHours(-1),
            ResolvedAt = resolvedAt
        };
        request.Items.Add(new ReturnRequestItem
        {
            Id = id + 1_000,
            ReturnRequestId = request.Id,
            ReturnRequest = request,
            OrderItemId = line.Id,
            OrderItem = line,
            Quantity = 1,
            RefundAmount = line.TotalPrice
        });
        return request;
    }
}
