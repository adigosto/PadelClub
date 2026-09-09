using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.DependencyInjection;
using PadelClub.Services.Database;
using PadelClub.WebAPI.Tests.Infrastructure;
using Xunit;

namespace PadelClub.WebAPI.Tests;

[Collection(SqlServerIntegrationCollection.Name)]
public class PlayerCityMigrationTests(SqlServerIntegrationFixture fixture)
{
    [Fact]
    public async Task Migration_preserves_existing_city_names_and_foreign_keys()
    {
        using var scope = fixture.Api.Services.CreateScope();
        var source = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
        var connection = new SqlConnectionStringBuilder(source.Database.GetConnectionString())
        { InitialCatalog = "CityMigration_" + Guid.NewGuid().ToString("N") };
        // This database lives only inside the disposable integration container.
        await using var db = new PadelClubContext(new DbContextOptionsBuilder<PadelClubContext>()
            .UseSqlServer(connection.ConnectionString).Options);
        await db.GetService<IMigrator>().MigrateAsync("20260908204930_AddReservationBusinessAudit");
        var user = new User { Username = "legacy-city", Email = "legacy@example.test" };
        db.Users.Add(user);
        await db.SaveChangesAsync();
        var city = "Travnik";
        await db.Database.ExecuteSqlInterpolatedAsync($"""
            INSERT INTO PlayerProfiles (UserId, SkillLevel, PreferredSide, City, Bio, Availability, IsDiscoverable, Rating, UpdatedAt)
            VALUES ({user.Id}, N'Beginner', N'Either', {city}, N'', N'', 1, 1000, SYSUTCDATETIME())
            """);
        await db.Database.MigrateAsync();
        var profile = await db.PlayerProfiles.Include(x => x.City).SingleAsync();
        Assert.Equal(city, profile.City.Name);
        Assert.True(profile.CityId > 0);
        Assert.Equal(1, await db.Cities.CountAsync(x => x.Name == city));
        Assert.True(await db.Cities.AnyAsync(x => x.Name == "Sarajevo"));
        await Assert.ThrowsAsync<SqlException>(() => db.Database.ExecuteSqlRawAsync(
            "UPDATE PlayerProfiles SET CityId = 2147483647"));
    }
}
