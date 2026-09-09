using Microsoft.EntityFrameworkCore;
using PadelClub.Services.Database;
using PadelClub.Services.Recommendations;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public sealed class RecommendationImpactTests
{
    [Fact]
    public async Task Impact_report_counts_orders_once_when_one_checkout_has_multiple_exposures()
    {
        var options = new DbContextOptionsBuilder<PadelClubContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;
        await using var db = new PadelClubContext(options);
        var now = DateTime.UtcNow;
        var player = new User
        {
            Id = 1,
            Username = "impact-player",
            Email = "impact-player@example.test",
            FirstName = "Impact",
            LastName = "Player",
            PasswordHash = "test",
            PasswordSalt = "test",
            IsActive = true
        };
        var firstProduct = Product(1, "Impact racket");
        var secondProduct = Product(2, "Impact balls");
        var deliveredOrder = Order(10, player, "Delivered", 42m);
        var cancelledOrder = Order(20, player, "Cancelled", 11m);
        db.Users.Add(player);
        db.Products.AddRange(firstProduct, secondProduct);
        db.Orders.AddRange(deliveredOrder, cancelledOrder);
        db.RecommendationExposures.AddRange(
            Exposure(player, firstProduct, now.AddDays(-20), deliveredOrder),
            Exposure(player, secondProduct, now.AddDays(-19), deliveredOrder),
            Exposure(player, firstProduct, now.AddDays(-18), cancelledOrder));
        await db.SaveChangesAsync();

        var response = await new RecommendationImpactService(db).GetAsync(
            new DateTimeOffset(now.AddDays(-30)),
            new DateTimeOffset(now.AddDays(-8)));

        Assert.Equal(3, response.Exposures);
        Assert.Equal(3, response.ClickedExposures);
        Assert.Equal(2, response.AttributedCheckouts);
        Assert.Equal(1, response.AttributedDeliveredOrders);
        Assert.Equal(1, response.AttributedCancelledOrders);
        Assert.Equal(42m, response.AttributedDeliveredRevenue);
        Assert.Equal(1d, response.ClickThroughRate);
        Assert.Equal(1d / 3d, response.DeliveredConversionRate!.Value, precision: 12);
        Assert.Equal("Collecting", response.EvidenceTier);
        Assert.False(response.IsMature);
        Assert.Contains(response.UnmetRequirements, requirement =>
            requirement.Contains("100 server-recorded exposures", StringComparison.Ordinal));
    }

    [Fact]
    public async Task Impact_report_excludes_non_operational_sources_and_invalid_click_timing()
    {
        var options = new DbContextOptionsBuilder<PadelClubContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;
        await using var db = new PadelClubContext(options);
        var now = DateTime.UtcNow;
        var player = new User
        {
            Id = 1,
            Username = "impact-provenance-player",
            Email = "impact-provenance-player@example.test",
            FirstName = "Impact",
            LastName = "Player",
            PasswordHash = "test",
            PasswordSalt = "test",
            IsActive = true
        };
        var product = Product(1, "Impact provenance racket");
        db.Users.Add(player);
        db.Products.Add(product);
        db.RecommendationExposures.AddRange(
            Exposure(player, product, now.AddDays(-24), source: RecommendationTelemetrySource.OperationalCustomer),
            Exposure(
                player,
                product,
                now.AddDays(-23),
                source: RecommendationTelemetrySource.OperationalCustomer,
                clickedAtUtc: now.AddDays(-15)),
            Exposure(player, product, now.AddDays(-22), source: RecommendationTelemetrySource.DevelopmentDemo),
            Exposure(player, product, now.AddDays(-21), source: RecommendationTelemetrySource.IntegrationTest),
            Exposure(player, product, now.AddDays(-20), source: RecommendationTelemetrySource.Administrator));
        await db.SaveChangesAsync();

        var response = await new RecommendationImpactService(db).GetAsync(
            new DateTimeOffset(now.AddDays(-30)),
            new DateTimeOffset(now.AddDays(-8)));

        Assert.Equal(2, response.Exposures);
        Assert.Equal(3, response.ExcludedNonOperationalExposures);
        Assert.Equal(1, response.ClickedExposures);
        Assert.Equal(1, response.InvalidClickTimingExposures);
        Assert.Equal(0.5d, response.ClickThroughRate);
        Assert.Equal(0, response.AttributedCheckouts);
        Assert.Contains(response.Limitations, limitation =>
            limitation.Contains("non-operational exposure", StringComparison.OrdinalIgnoreCase));
        Assert.Contains(response.Limitations, limitation =>
            limitation.Contains("invalid click timestamp", StringComparison.OrdinalIgnoreCase));
    }

    private static Product Product(int id, string name) => new()
    {
        Id = id,
        Name = name,
        Description = name,
        Price = 10m,
        StockQuantity = 10,
        ProductState = "ActiveProductState",
        IsActive = true
    };

    private static Order Order(int id, User user, string status, decimal total) => new()
    {
        Id = id,
        UserId = user.Id,
        User = user,
        OrderNumber = $"IMPACT-{id}",
        Status = status,
        RecipientName = "Impact Player",
        PhoneNumber = "000000000",
        ShippingAddress = "Test street 1",
        City = "Sarajevo",
        PostalCode = "71000",
        TotalAmount = total,
        SubtotalAmount = total,
        Origin = OrderOrigin.CustomerCheckout
    };

    private static RecommendationExposure Exposure(
        User user,
        Product product,
        DateTime servedAtUtc,
        Order? order = null,
        RecommendationTelemetrySource source = RecommendationTelemetrySource.OperationalCustomer,
        DateTime? clickedAtUtc = null) => new()
    {
        UserId = user.Id,
        User = user,
        ProductId = product.Id,
        Product = product,
        AlgorithmVersion = "item-cf-cosine-v1",
        Strategy = "collaborative-filtering",
        Rank = 1,
        ServedAtUtc = servedAtUtc,
        TelemetrySource = source,
        ClickedAtUtc = clickedAtUtc ?? servedAtUtc.AddMinutes(1),
        PurchasedOrderId = order?.Id,
        PurchasedOrder = order,
        PurchasedAtUtc = order is null ? null : servedAtUtc.AddMinutes(2)
    };
}
