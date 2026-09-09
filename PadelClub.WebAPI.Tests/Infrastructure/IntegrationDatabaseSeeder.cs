using PadelClub.Services;
using PadelClub.Services.Database;

namespace PadelClub.WebAPI.Tests.Infrastructure;

public sealed record IntegrationSeed(
    string AdminUsername,
    string PlayerUsername,
    string Password,
    int AdminUserId,
    int PlayerUserId,
    int OwnedProductId,
    int RecommendedProductId,
    int InventoryProductId,
    int InventoryStartingQuantity,
    int DraftProductId,
    DateTimeOffset EvaluationCutoffUtc,
    DateTimeOffset EvaluationEndUtc);

internal static class IntegrationDatabaseSeeder
{
    private const string Password = "IntegrationPassword!123";

    public static IntegrationSeed Seed(PadelClubContext database)
    {
        var now = DateTime.UtcNow;
        var hasher = new PasswordHasher();
        var passwordHash = hasher.HashPassword(Password);

        var administratorRole = new Role { Name = "Administrator", Description = "Integration administrator" };
        var playerRole = new Role { Name = "Player", Description = "Integration player" };
        database.Roles.AddRange(administratorRole, playerRole);

        var administrator = User("integration-admin", "admin@integration.test", passwordHash, now);
        var player = User("integration-player", "player@integration.test", passwordHash, now);
        var peerOne = User("integration-peer-one", "peer-one@integration.test", passwordHash, now);
        var peerTwo = User("integration-peer-two", "peer-two@integration.test", passwordHash, now);
        var demoOnlyUser = User("integration-demo-only", "demo-only@integration.test", passwordHash, now);
        database.Users.AddRange(administrator, player, peerOne, peerTwo, demoOnlyUser);
        database.SaveChanges();

        database.UserRoles.AddRange(
            new UserRole { UserId = administrator.Id, RoleId = administratorRole.Id },
            new UserRole { UserId = player.Id, RoleId = playerRole.Id });

        var category = new ProductCategory { Name = "Integration equipment", Description = "HTTP test catalog" };
        var type = new ProductType { Name = "Integration rackets", Description = "HTTP test catalog" };
        database.ProductCategories.Add(category);
        database.ProductTypes.Add(type);
        database.SaveChanges();

        var ownedRacket = Product("Integration Control Racket", 12, category.Id, type.Id, "ActiveProductState", now);
        var recommendedRacket = Product("Integration Power Racket", 10, category.Id, type.Id, "ActiveProductState", now);
        var zeroStockRacket = Product("Integration Zero Stock Racket", 0, category.Id, type.Id, "ActiveProductState", now);
        var deactivatedRacket = Product("Integration Deactivated Racket", 20, category.Id, type.Id, "DeactivatedProductState", now);
        var draftRacket = Product("Integration Draft Racket", 8, category.Id, type.Id, "DraftProductState", now);
        database.Products.AddRange(ownedRacket, recommendedRacket, zeroStockRacket, deactivatedRacket, draftRacket);
        database.SaveChanges();

        var evaluationCutoff = new DateTimeOffset(now.AddDays(-30), TimeSpan.Zero);
        var evaluationEnd = new DateTimeOffset(now.AddDays(-20), TimeSpan.Zero);
        var playerPurchase = DeliveredOrder(player, "IT-PLAYER-001", now.AddDays(-4));
        var peerOnePurchase = DeliveredOrder(peerOne, "IT-PEER-001", now.AddDays(-5));
        var peerTwoPurchase = DeliveredOrder(peerTwo, "IT-PEER-002", now.AddDays(-6));
        var demoEvaluationOrder = DeliveredOrder(demoOnlyUser, "DEMO-INTEGRATION-EVAL-001", evaluationCutoff.UtcDateTime.AddDays(-2));
        demoEvaluationOrder.IsSeededForDemo = true;
        demoEvaluationOrder.Origin = OrderOrigin.SeedDemo;
        database.Orders.AddRange(playerPurchase, peerOnePurchase, peerTwoPurchase, demoEvaluationOrder);
        database.SaveChanges();

        database.OrderItems.AddRange(
            OrderItem(playerPurchase, ownedRacket),
            OrderItem(peerOnePurchase, ownedRacket),
            OrderItem(peerOnePurchase, recommendedRacket),
            OrderItem(peerTwoPurchase, ownedRacket),
            OrderItem(peerTwoPurchase, recommendedRacket),
            OrderItem(demoEvaluationOrder, recommendedRacket));
        database.SaveChanges();

        return new IntegrationSeed(
            administrator.Username,
            player.Username,
            Password,
            administrator.Id,
            player.Id,
            ownedRacket.Id,
            recommendedRacket.Id,
            recommendedRacket.Id,
            recommendedRacket.StockQuantity,
            draftRacket.Id,
            evaluationCutoff,
            evaluationEnd);
    }

    private static User User(string username, string email, string passwordHash, DateTime createdAt) => new()
    {
        Username = username,
        Email = email,
        FirstName = "Integration",
        LastName = "User",
        PasswordHash = passwordHash,
        PasswordSalt = string.Empty,
        IsActive = true,
        EmailVerifiedAt = createdAt,
        CreatedAt = createdAt
    };

    private static Product Product(
        string name,
        int stockQuantity,
        int categoryId,
        int typeId,
        string productState,
        DateTime createdAt) => new()
    {
        Name = name,
        Description = name,
        Price = 100m,
        StockQuantity = stockQuantity,
        ProductCategoryId = categoryId,
        ProductTypeId = typeId,
        ProductState = productState,
        IsActive = true,
        CreatedAt = createdAt
    };

    private static Order DeliveredOrder(User user, string orderNumber, DateTime deliveredAt) => new()
    {
        UserId = user.Id,
        OrderNumber = orderNumber,
        Status = "Delivered",
        RecipientName = "Integration User",
        PhoneNumber = "+38760000000",
        ShippingAddress = "Integration Street 1",
        City = "Sarajevo",
        PostalCode = "71000",
        TotalAmount = 100m,
        SubtotalAmount = 100m,
        DiscountAmount = 0m,
        CreatedAt = deliveredAt,
        DeliveredAt = deliveredAt,
        Origin = OrderOrigin.IntegrationTest
    };

    private static OrderItem OrderItem(Order order, Product product) => new()
    {
        OrderId = order.Id,
        ProductId = product.Id,
        Quantity = 1,
        UnitPrice = product.Price,
        TotalPrice = product.Price,
        CreatedAt = order.DeliveredAt!.Value
    };
}
