using Microsoft.EntityFrameworkCore;
using PadelClub.Model.Responses;
using PadelClub.Services.Database;
using PadelClub.Services.Recommendations;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public sealed class RecommendationCohortReadinessTests
{
    [Fact]
    public async Task Readiness_reports_operational_collection_gaps_without_promoting_ineligible_orders()
    {
        var options = new DbContextOptionsBuilder<PadelClubContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;
        await using var db = new PadelClubContext(options);
        var now = DateTime.UtcNow;
        var firstCustomer = User(1, "cohort-customer-one");
        var secondCustomer = User(2, "cohort-customer-two");
        var demoCustomer = User(3, "cohort-demo");
        var productOne = Product(10, "Cohort racket");
        var productTwo = Product(20, "Cohort balls");
        db.Users.AddRange(firstCustomer, secondCustomer, demoCustomer);
        db.Products.AddRange(productOne, productTwo);

        var deliveredOne = Order(100, firstCustomer, now.AddDays(-200), OrderOrigin.CustomerCheckout);
        var deliveredTwo = Order(200, secondCustomer, now.AddDays(-190), OrderOrigin.CustomerCheckout);
        var deliveredWithoutTimestamp = Order(300, firstCustomer, null, OrderOrigin.CustomerCheckout);
        var awaitingDelivery = Order(400, secondCustomer, now.AddDays(-5), OrderOrigin.CustomerCheckout, "Shipped");
        var demoOrder = Order(500, demoCustomer, now.AddDays(-180), OrderOrigin.SeedDemo);
        demoOrder.IsSeededForDemo = true;
        var legacyOrder = Order(600, demoCustomer, now.AddDays(-180), OrderOrigin.UnverifiedLegacy);
        var testOrder = Order(700, demoCustomer, now.AddDays(-180), OrderOrigin.IntegrationTest);
        var adminOrder = Order(800, demoCustomer, now.AddDays(-180), OrderOrigin.AdminCreated);
        db.Orders.AddRange(
            deliveredOne,
            deliveredTwo,
            deliveredWithoutTimestamp,
            awaitingDelivery,
            demoOrder,
            legacyOrder,
            testOrder,
            adminOrder);

        var deliveredOneLine = Line(1000, deliveredOne, productOne);
        db.OrderItems.AddRange(
            deliveredOneLine,
            Line(2000, deliveredTwo, productOne),
            Line(2001, deliveredTwo, productTwo),
            Line(3000, deliveredWithoutTimestamp, productTwo),
            Line(5000, demoOrder, productTwo));
        var unresolvedApprovedReturn = new ReturnRequest
        {
            Id = 900,
            OrderId = deliveredOne.Id,
            Order = deliveredOne,
            UserId = firstCustomer.Id,
            Status = "Approved",
            Reason = "Timestamp integrity fixture",
            CreatedAt = now.AddDays(-10),
            ResolvedAt = null
        };
        unresolvedApprovedReturn.Items.Add(new ReturnRequestItem
        {
            Id = 901,
            ReturnRequestId = unresolvedApprovedReturn.Id,
            ReturnRequest = unresolvedApprovedReturn,
            OrderItemId = deliveredOneLine.Id,
            OrderItem = deliveredOneLine,
            Quantity = 1,
            RefundAmount = deliveredOneLine.TotalPrice
        });
        db.ReturnRequests.Add(unresolvedApprovedReturn);
        await db.SaveChangesAsync();

        var response = await new RecommendationCohortReadinessService(db).GetReadinessAsync();

        Assert.Equal("Operational", response.EvidenceSource);
        Assert.Equal("DataQualityBlocked", response.ReadinessState);
        Assert.False(response.IsReadyForWindowValidation);
        Assert.Equal(4, response.Cohort.CustomerCheckoutOrders);
        Assert.Equal(2, response.Cohort.EligibleDeliveredOrders);
        Assert.Equal(2, response.Cohort.MaturedEligibleDeliveredOrders);
        Assert.Equal(3, response.Cohort.EligibleRetainedPurchaseSignals);
        Assert.Equal(1, response.Cohort.OperationalOrdersAwaitingDelivery);
        Assert.Equal(1, response.Cohort.EligibleDeliveredOrdersMissingDeliveredAt);
        Assert.Equal(1, response.Cohort.ApprovedOrRefundedReturnsMissingResolvedAt);
        Assert.Equal(1, response.Cohort.ExcludedSeededDemoOrders);
        Assert.Equal(1, response.Cohort.ExcludedUnverifiedLegacyOrders);
        Assert.Equal(2, response.Cohort.ExcludedNonOperationalOrders);
        Assert.True(response.EarliestTimeOnlyWindowValidationAtUtc <= response.GeneratedAtUtc);
        Assert.Equal(
            "Gap",
            response.Requirements.Single(item => item.Name == "delivery-timestamps").Status);
        Assert.Equal(
            "Gap",
            response.Requirements.Single(item => item.Name == "return-resolution-timestamps").Status);
        Assert.Equal(
            "RequiresEvaluationWindow",
            response.Requirements.Single(item => item.Name == "split-specific-evidence").Status);
        Assert.Contains(response.NextActions, action => action.Contains("Never backfill DeliveredAt", StringComparison.Ordinal));
    }

    [Fact]
    public async Task Readiness_can_be_collection_ready_but_still_requires_a_temporal_evaluation()
    {
        var options = new DbContextOptionsBuilder<PadelClubContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;
        await using var db = new PadelClubContext(options);
        var deliveredAt = DateTime.UtcNow.AddDays(-200);
        var products = Enumerable.Range(1, RecommendationEvaluationQualityPolicy.MinimumCandidateProducts)
            .Select(index => Product(index, $"Cohort product {index}"))
            .ToArray();
        var users = Enumerable.Range(1, RecommendationEvaluationQualityPolicy.MinimumDistinctCustomers)
            .Select(index => User(index, $"collection-ready-{index}"))
            .ToArray();
        db.Products.AddRange(products);
        db.Users.AddRange(users);

        var orderId = 1;
        var orderItemId = 1;
        foreach (var user in users)
        {
            for (var purchase = 0; purchase < 4; purchase++)
            {
                var order = Order(orderId++, user, deliveredAt.AddDays(purchase), OrderOrigin.CustomerCheckout);
                var product = products[(user.Id + purchase) % products.Length];
                db.Orders.Add(order);
                db.OrderItems.Add(Line(orderItemId++, order, product));
            }
        }
        await db.SaveChangesAsync();

        var response = await new RecommendationCohortReadinessService(db).GetReadinessAsync();

        Assert.Equal("ReadyForWindowValidation", response.ReadinessState);
        Assert.True(response.IsReadyForWindowValidation);
        Assert.Equal(120, response.Cohort.EligibleDeliveredOrders);
        Assert.Equal(30, response.Cohort.EligibleDistinctCustomers);
        Assert.Equal(20, response.Cohort.EligibleDistinctProducts);
        Assert.Equal(20, response.Cohort.EligibleProductsWithAtLeastTwoDistinctBuyers);
        Assert.Equal(
            "RequiresEvaluationWindow",
            response.Requirements.Single(item => item.Name == "split-specific-evidence").Status);
        Assert.Contains(response.NextActions, action => action.Contains("Do not label this preflight", StringComparison.Ordinal));
        Assert.Contains(response.Limitations, limitation => limitation.Contains("not a recommendation-quality metric", StringComparison.Ordinal));
    }

    private static User User(int id, string username) => new()
    {
        Id = id,
        Username = username,
        Email = $"{username}@example.test",
        FirstName = "Cohort",
        LastName = "Customer",
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

    private static Order Order(
        int id,
        User user,
        DateTime? deliveredAt,
        OrderOrigin origin,
        string status = "Delivered") => new()
    {
        Id = id,
        UserId = user.Id,
        User = user,
        OrderNumber = $"COHORT-{id}",
        Status = status,
        DeliveredAt = deliveredAt,
        CreatedAt = deliveredAt ?? DateTime.UtcNow,
        TotalAmount = 10m,
        SubtotalAmount = 10m,
        RecipientName = "Cohort Customer",
        PhoneNumber = "000000000",
        ShippingAddress = "Test street 1",
        City = "Sarajevo",
        PostalCode = "71000",
        Origin = origin
    };

    private static OrderItem Line(int id, Order order, Product product) => new()
    {
        Id = id,
        OrderId = order.Id,
        Order = order,
        ProductId = product.Id,
        Product = product,
        Quantity = 1,
        UnitPrice = 10m,
        TotalPrice = 10m,
        CreatedAt = order.DeliveredAt ?? order.CreatedAt
    };
}
