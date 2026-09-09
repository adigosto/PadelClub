using Microsoft.EntityFrameworkCore;
using PadelClub.Model.Responses;
using PadelClub.Services.Database;
using PadelClub.Services.Recommendations;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public class ProductRecommendationServiceTests
{
    [Theory]
    [InlineData(OrderOrigin.SeedDemo, true)]
    [InlineData(OrderOrigin.CustomerCheckout, true)]
    [InlineData(OrderOrigin.UnverifiedLegacy, false)]
    [InlineData(OrderOrigin.AdminCreated, false)]
    public async Task Untrusted_history_does_not_change_online_recommendations(OrderOrigin origin, bool seeded)
    {
        await using var db = new PadelClubContext(new DbContextOptionsBuilder<PadelClubContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var user = User(1, "customer");
        var product = Product(10, "Racket", 10, "ActiveProductState");
        db.AddRange(user, product);
        await db.SaveChangesAsync();
        var before = await new ProductRecommendationService(db).GetForUserAsync(user.Id, limit: 6);
        var order = Order(100, user, "UNTRUSTED");
        order.Origin = origin;
        order.IsSeededForDemo = seeded;
        db.Add(OrderItem(1000, order, product, 10));
        await db.SaveChangesAsync();
        var after = await new ProductRecommendationService(db).GetForUserAsync(user.Id, limit: 6);
        Assert.Equal(before.Select(x => (x.Product.Id, x.Strategy, x.IsFallback)),
            after.Select(x => (x.Product.Id, x.Strategy, x.IsFallback)));
    }

    [Fact]
    public async Task Uses_delivered_net_purchase_history_and_only_recommendable_products()
    {
        var options = new DbContextOptionsBuilder<PadelClubContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;
        await using var db = new PadelClubContext(options);

        var target = User(1, "target");
        var peerOne = User(2, "peer-one");
        var peerTwo = User(3, "peer-two");
        db.Users.AddRange(target, peerOne, peerTwo);

        var grip = Product(10, "Grip", stock: 10, state: "ActiveProductState");
        var balls = Product(20, "Balls", stock: 10, state: "ActiveProductState");
        var returnedRacket = Product(30, "Returned racket", stock: 4, state: "ActiveProductState");
        var deactivated = Product(40, "Deactivated item", stock: 6, state: "DeactivatedProductState");
        var outOfStock = Product(50, "Out of stock item", stock: 0, state: "ActiveProductState");
        db.Products.AddRange(grip, balls, returnedRacket, deactivated, outOfStock);

        var targetOrder = Order(100, target, "TARGET-1");
        var peerOneOrder = Order(200, peerOne, "PEER-1");
        var peerTwoOrder = Order(300, peerTwo, "PEER-2");
        db.Orders.AddRange(targetOrder, peerOneOrder, peerTwoOrder);

        var targetGrip = OrderItem(1000, targetOrder, grip, quantity: 1);
        var targetReturnedRacket = OrderItem(1001, targetOrder, returnedRacket, quantity: 1);
        db.OrderItems.AddRange(
            targetGrip,
            targetReturnedRacket,
            OrderItem(2000, peerOneOrder, grip, quantity: 1),
            OrderItem(2001, peerOneOrder, balls, quantity: 1),
            OrderItem(3000, peerTwoOrder, grip, quantity: 1),
            OrderItem(3001, peerTwoOrder, balls, quantity: 1));

        var approvedReturn = new ReturnRequest
        {
            Id = 900,
            OrderId = targetOrder.Id,
            UserId = target.Id,
            Status = "Approved",
            Reason = "Does not fit",
            Order = targetOrder
        };
        db.ReturnRequests.Add(approvedReturn);
        db.ReturnRequestItems.Add(new ReturnRequestItem
        {
            Id = 901,
            ReturnRequestId = approvedReturn.Id,
            OrderItemId = targetReturnedRacket.Id,
            Quantity = 1,
            ReturnRequest = approvedReturn,
            OrderItem = targetReturnedRacket
        });
        await db.SaveChangesAsync();

        var recommendations = await new ProductRecommendationService(db)
            .GetForUserAsync(target.Id, limit: 6);

        var collaborative = Assert.Single(recommendations, x => !x.IsFallback);
        Assert.Equal(balls.Id, collaborative.Product.Id);
        Assert.Equal("collaborative-filtering", collaborative.Strategy);
        Assert.Contains("Grip", collaborative.Reason);

        Assert.DoesNotContain(recommendations, x => x.Product.Id == grip.Id);
        Assert.DoesNotContain(recommendations, x => x.Product.Id == deactivated.Id);
        Assert.DoesNotContain(recommendations, x => x.Product.Id == outOfStock.Id);

        var returnedProduct = Assert.Single(recommendations, x => x.Product.Id == returnedRacket.Id);
        Assert.True(returnedProduct.IsFallback);
    }

    [Fact]
    public async Task Expired_click_is_rejected_without_mutating_the_historical_exposure()
    {
        var options = new DbContextOptionsBuilder<PadelClubContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;
        await using var db = new PadelClubContext(options);
        var player = User(1, "expired-click-player");
        var product = Product(10, "Expired click racket", stock: 10, state: "ActiveProductState");
        var exposure = new RecommendationExposure
        {
            UserId = player.Id,
            User = player,
            ProductId = product.Id,
            Product = product,
            AlgorithmVersion = "item-cf-cosine-v1",
            Strategy = "collaborative-filtering",
            Rank = 1,
            ServedAtUtc = DateTime.UtcNow.AddDays(-RecommendationImpactPolicy.AttributionWindowDays - 1),
            TelemetrySource = RecommendationTelemetrySource.OperationalCustomer
        };
        db.Users.Add(player);
        db.Products.Add(product);
        db.RecommendationExposures.Add(exposure);
        await db.SaveChangesAsync();

        var recorded = await new ProductRecommendationService(db)
            .RecordClickAsync(player.Id, exposure.Id);

        Assert.False(recorded);
        Assert.Null(exposure.ClickedAtUtc);
    }

    [Fact]
    public async Task Production_exposures_are_server_stamped_for_verified_players_but_not_administrators()
    {
        var options = new DbContextOptionsBuilder<PadelClubContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;
        await using var db = new PadelClubContext(options);
        var player = User(1, "operational-telemetry-player");
        player.EmailVerifiedAt = DateTime.UtcNow;
        var administrator = User(2, "operational-telemetry-admin");
        administrator.EmailVerifiedAt = DateTime.UtcNow;
        var playerRole = new Role { Id = 10, Name = "Player", Description = "Player", IsActive = true };
        var administratorRole = new Role { Id = 20, Name = "Administrator", Description = "Administrator", IsActive = true };
        var product = Product(10, "Telemetry racket", stock: 10, state: "ActiveProductState");
        db.Users.AddRange(player, administrator);
        db.Roles.AddRange(playerRole, administratorRole);
        db.Products.Add(product);
        await db.SaveChangesAsync();
        db.UserRoles.AddRange(
            new UserRole { UserId = player.Id, RoleId = playerRole.Id },
            new UserRole { UserId = administrator.Id, RoleId = administratorRole.Id });
        db.Orders.Add(new Order
        {
            UserId = player.Id,
            OrderNumber = "OPERATIONAL-TELEMETRY-001",
            Status = "Pending",
            RecipientName = "Operational Player",
            PhoneNumber = "000000000",
            ShippingAddress = "Test street 1",
            City = "Sarajevo",
            PostalCode = "71000",
            TotalAmount = 10m,
            SubtotalAmount = 10m,
            Origin = OrderOrigin.CustomerCheckout,
            IsSeededForDemo = false
        });
        await db.SaveChangesAsync();

        var service = new ProductRecommendationService(
            db,
            new RecommendationTelemetryEnvironment("Production"));
        await service.GetForUserAsync(player.Id, limit: 1);
        await service.GetForUserAsync(administrator.Id, limit: 1);

        Assert.Equal(
            RecommendationTelemetrySource.OperationalCustomer,
            await db.RecommendationExposures
                .Where(exposure => exposure.UserId == player.Id)
                .Select(exposure => exposure.TelemetrySource)
                .SingleAsync());
        Assert.Equal(
            RecommendationTelemetrySource.Administrator,
            await db.RecommendationExposures
                .Where(exposure => exposure.UserId == administrator.Id)
                .Select(exposure => exposure.TelemetrySource)
                .SingleAsync());
    }

    [Fact]
    public async Task Consented_control_assignment_serves_the_full_popularity_baseline_and_persists_its_assignment()
    {
        var options = new DbContextOptionsBuilder<PadelClubContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;
        await using var db = new PadelClubContext(options);
        var target = User(1, "control-player");
        target.EmailVerifiedAt = DateTime.UtcNow;
        var peerOne = User(2, "control-peer-one");
        var peerTwo = User(3, "control-peer-two");
        var playerRole = new Role { Id = 10, Name = "Player", Description = "Player", IsActive = true };
        var owned = Product(10, "Owned racket", stock: 10, state: "ActiveProductState");
        var popular = Product(20, "Popular balls", stock: 10, state: "ActiveProductState");
        var lessPopular = Product(30, "Less popular grip", stock: 10, state: "ActiveProductState");
        db.Users.AddRange(target, peerOne, peerTwo);
        db.Roles.Add(playerRole);
        db.Products.AddRange(owned, popular, lessPopular);
        await db.SaveChangesAsync();
        db.UserRoles.Add(new UserRole { UserId = target.Id, RoleId = playerRole.Id });
        var targetOrder = Order(100, target, "CONTROL-TARGET");
        targetOrder.Origin = OrderOrigin.CustomerCheckout;
        var peerOneOrder = Order(200, peerOne, "CONTROL-PEER-1");
        var peerTwoOrder = Order(300, peerTwo, "CONTROL-PEER-2");
        db.Orders.AddRange(targetOrder, peerOneOrder, peerTwoOrder);
        db.OrderItems.AddRange(
            OrderItem(1000, targetOrder, owned, quantity: 1),
            OrderItem(2000, peerOneOrder, popular, quantity: 1),
            OrderItem(2001, peerOneOrder, lessPopular, quantity: 1),
            OrderItem(3000, peerTwoOrder, popular, quantity: 1));
        await db.SaveChangesAsync();

        var assignmentId = Guid.NewGuid();
        var experiment = new FixedExperimentService(new RecommendationExperimentAssignmentContext(
            assignmentId,
            RecommendationExperimentVariant.Control,
            PopularityRecommendationRanker.Version,
            RecommendationExperimentPolicy.ControlStrategy));
        var service = new ProductRecommendationService(
            db,
            new RecommendationTelemetryEnvironment("Production"),
            experiment);

        var recommendations = await service.GetForUserAsync(target.Id, limit: 6);

        Assert.Equal(RecommendationTelemetrySource.OperationalCustomer, experiment.LastTelemetrySource);
        Assert.NotEmpty(recommendations);
        Assert.All(recommendations, recommendation =>
        {
            Assert.Equal(RecommendationExperimentPolicy.ControlStrategy, recommendation.Strategy);
            Assert.Equal(PopularityRecommendationRanker.Version, recommendation.AlgorithmVersion);
            Assert.False(recommendation.IsFallback);
        });
        Assert.DoesNotContain(recommendations, recommendation => recommendation.Product.Id == owned.Id);
        Assert.Equal(popular.Id, recommendations.First().Product.Id);
        Assert.All(
            await db.RecommendationExposures.ToListAsync(),
            exposure => Assert.Equal(assignmentId, exposure.ExperimentAssignmentId));
    }

    private static User User(int id, string username) => new()
    {
        Id = id,
        Username = username,
        Email = $"{username}@example.test",
        FirstName = username,
        LastName = "Player",
        PasswordHash = "test-hash",
        PasswordSalt = "test-salt",
        IsActive = true
    };

    private static Product Product(int id, string name, int stock, string state) => new()
    {
        Id = id,
        Name = name,
        Description = $"{name} description",
        Price = 10m,
        StockQuantity = stock,
        IsActive = true,
        ProductState = state,
        CreatedAt = DateTime.UtcNow
    };

    private static Order Order(int id, User user, string number) => new()
    {
        Id = id,
        UserId = user.Id,
        User = user,
        OrderNumber = number,
        Status = "Delivered",
        Origin = OrderOrigin.CustomerCheckout,
        DeliveredAt = DateTime.UtcNow,
        TotalAmount = 10m,
        RecipientName = user.FirstName,
        PhoneNumber = "000000000",
        ShippingAddress = "Test street 1",
        City = "Sarajevo",
        PostalCode = "71000"
    };

    private static OrderItem OrderItem(int id, Order order, Product product, int quantity) => new()
    {
        Id = id,
        OrderId = order.Id,
        Order = order,
        ProductId = product.Id,
        Product = product,
        Quantity = quantity,
        UnitPrice = product.Price,
        TotalPrice = product.Price * quantity
    };

    private sealed class FixedExperimentService(RecommendationExperimentAssignmentContext assignment)
        : IRecommendationExperimentService
    {
        public RecommendationTelemetrySource? LastTelemetrySource { get; private set; }

        public Task<RecommendationExperimentAssignmentContext?> GetActiveAssignmentAsync(
            int userId,
            RecommendationTelemetrySource telemetrySource,
            int recommendationLimit,
            CancellationToken cancellationToken = default)
        {
            LastTelemetrySource = telemetrySource;
            return Task.FromResult<RecommendationExperimentAssignmentContext?>(assignment);
        }

        public Task<RecommendationAnalyticsConsentResponse> GetConsentAsync(int userId, CancellationToken cancellationToken = default) =>
            throw new NotSupportedException();

        public Task<RecommendationAnalyticsConsentResponse> SetConsentAsync(int userId, bool isGranted, CancellationToken cancellationToken = default) =>
            throw new NotSupportedException();

        public Task<RecommendationExperimentResponse> CreateAsync(int createdByUserId, CancellationToken cancellationToken = default) =>
            throw new NotSupportedException();

        public Task<RecommendationExperimentResponse?> GetAsync(Guid experimentId, CancellationToken cancellationToken = default) =>
            throw new NotSupportedException();

        public Task<RecommendationExperimentResponse> StartAsync(Guid experimentId, CancellationToken cancellationToken = default) =>
            throw new NotSupportedException();

        public Task<RecommendationExperimentResponse> CloseAsync(Guid experimentId, CancellationToken cancellationToken = default) =>
            throw new NotSupportedException();

        public Task<RecommendationExperimentImpactResponse?> GetImpactAsync(Guid experimentId, CancellationToken cancellationToken = default) =>
            throw new NotSupportedException();

        public Task<RecommendationExperimentAnalysisRunResponse?> CreateAnalysisRunAsync(int executedByUserId, Guid experimentId, CancellationToken cancellationToken = default) =>
            throw new NotSupportedException();

        public Task<RecommendationExperimentAnalysisRunResponse?> GetLatestAnalysisRunAsync(Guid experimentId, CancellationToken cancellationToken = default) =>
            throw new NotSupportedException();
    }
}
