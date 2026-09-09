using Mapster;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;
using PadelClub.Services.Database;
using PadelClub.WebAPI.Controllers;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public class BusinessDeletionPolicyTests
{
    [Fact]
    public async Task Generic_CRUD_cannot_delete_business_history_or_active_records()
    {
        await using var db = new PadelClubContext(new DbContextOptionsBuilder<PadelClubContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var order = new Order { Status = "Pending" };
        var membership = new Membership { Status = "Active" };
        var user = new User { Username = "active", IsActive = true };
        db.AddRange(order, membership, user);
        await db.SaveChangesAsync();
        await Assert.ThrowsAsync<InvalidOperationException>(() => new DeleteProbe<Order>(db).DeleteAsync(order.Id));
        await Assert.ThrowsAsync<InvalidOperationException>(() => new DeleteProbe<Membership>(db).DeleteAsync(membership.Id));
        await Assert.ThrowsAsync<InvalidOperationException>(() => new DeleteProbe<OrderItem>(db).DeleteAsync(1));
        await Assert.ThrowsAsync<InvalidOperationException>(() => new DeleteProbe<User>(db).DeleteAsync(user.Id));
        Assert.Equal(1, await db.Orders.CountAsync());
        Assert.Equal(1, await db.Memberships.CountAsync());
        Assert.Equal(1, await db.Users.CountAsync());
    }

    [Theory]
    [InlineData(typeof(CommerceOperationsController))]
    [InlineData(typeof(PlayerExperienceController))]
    [InlineData(typeof(PrivacyController))]
    public void Controllers_depend_on_workflows_instead_of_database_contexts(Type controller)
    {
        Assert.DoesNotContain(controller.GetConstructors().SelectMany(x => x.GetParameters()),
            parameter => typeof(DbContext).IsAssignableFrom(parameter.ParameterType));
    }

    private sealed class DeleteProbe<T>(PadelClubContext db)
        : BaseCRUDService<object, BaseSearchObject, T, object, object>(db, new Mapper(new TypeAdapterConfig()))
        where T : class, new();
}
