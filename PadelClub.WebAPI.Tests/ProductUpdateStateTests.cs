using System.Reflection;
using Mapster;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using System.Text.Json;
using PadelClub.Model.Messages;
using PadelClub.Model.Requests;
using PadelClub.Services;
using PadelClub.Services.Database;
using PadelClub.Services.Outbox;
using PadelClub.Services.ProductStateMachine;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public class ProductUpdateStateTests
{
    [Fact]
    public async Task Draft_product_update_with_omitted_relation_ids_preserves_existing_foreign_keys()
    {
        await using var db = CreateDatabase();
        await SeedProductAsync(db, categoryId: 11, typeId: 22);
        using var provider = CreateStateProvider(db);
        var service = CreateProductService(db, provider);

        var updated = await service.UpdateAsync(33, new ProductUpdateRequest
        {
            Name = "Updated draft product",
            Description = "Updated without relation IDs",
            Price = 19.95m,
            StockQuantity = 4
        });

        Assert.NotNull(updated);
        db.ChangeTracker.Clear();
        var persisted = await db.Products.SingleAsync(x => x.Id == 33);
        Assert.Equal(11, persisted.ProductCategoryId);
        Assert.Equal(22, persisted.ProductTypeId);
        Assert.Equal("Updated draft product", persisted.Name);
        Assert.Equal(19.95m, persisted.Price);
        var outbox = Assert.Single(await db.OutboxMessages.ToListAsync());
        Assert.Equal(OutboxMessageTypes.ProductUpdated, outbox.Type);
        Assert.Null(outbox.PublishedAtUtc);
        var payload = JsonSerializer.Deserialize<ProductUpdated>(outbox.Payload);
        Assert.NotNull(payload);
        Assert.Equal(outbox.Id, payload.EventId);
        Assert.Equal(persisted.Id, payload.Product.Id);
        Assert.Equal(persisted.Name, payload.Product.Name);
    }

    [Fact]
    public async Task Draft_product_update_can_change_one_relation_without_overwriting_the_other()
    {
        await using var db = CreateDatabase();
        await SeedProductAsync(db, categoryId: 11, typeId: 22);
        db.ProductCategories.Add(new ProductCategory
        {
            Id = 12,
            Name = "Accessories",
            IsActive = true
        });
        await db.SaveChangesAsync();
        using var provider = CreateStateProvider(db);
        var service = CreateProductService(db, provider);

        var updated = await service.UpdateAsync(33, new ProductUpdateRequest
        {
            Name = "Updated draft product",
            Description = "Only category changes",
            Price = 19.95m,
            StockQuantity = 4,
            ProductCategoryId = 12
        });

        Assert.NotNull(updated);
        db.ChangeTracker.Clear();
        var persisted = await db.Products.SingleAsync(x => x.Id == 33);
        Assert.Equal(12, persisted.ProductCategoryId);
        Assert.Equal(22, persisted.ProductTypeId);
    }

    private static PadelClubContext CreateDatabase() => new(
        new DbContextOptionsBuilder<PadelClubContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options);

    private static async Task SeedProductAsync(PadelClubContext db, int categoryId, int typeId)
    {
        db.ProductCategories.Add(new ProductCategory
        {
            Id = categoryId,
            Name = "Rackets",
            IsActive = true
        });
        db.ProductTypes.Add(new ProductType
        {
            Id = typeId,
            Name = "Equipment",
            IsActive = true
        });
        db.Products.Add(new Product
        {
            Id = 33,
            Name = "Draft product",
            Description = "Original description",
            Price = 15m,
            StockQuantity = 5,
            ProductCategoryId = categoryId,
            ProductTypeId = typeId,
            ProductState = nameof(DraftProductState),
            IsActive = true
        });
        await db.SaveChangesAsync();
    }

    private static ServiceProvider CreateStateProvider(PadelClubContext db)
    {
        var mapper = new Mapper(new TypeAdapterConfig());
        return new ServiceCollection()
            .AddSingleton(db)
            .AddSingleton<IMapper>(mapper)
            .AddTransient<BaseProductState>()
            .AddTransient<DraftProductState>()
            .BuildServiceProvider();
    }

    private static ProductService CreateProductService(PadelClubContext db, ServiceProvider provider) => new(
        db,
        provider.GetRequiredService<IMapper>(),
        provider.GetRequiredService<BaseProductState>());
}
