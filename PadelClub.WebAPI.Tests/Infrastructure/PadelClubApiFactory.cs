using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
using PadelClub.Services.Database;
using PadelClub.WebAPI;

namespace PadelClub.WebAPI.Tests.Infrastructure;

/// <summary>
/// Hosts the production API pipeline with a disposable, independently migrated
/// SQL Server database. Application bootstrap data and long-running workers are
/// deliberately disabled so each integration scenario is deterministic.
/// </summary>
public sealed class PadelClubApiFactory : WebApplicationFactory<Program>
{
    private readonly string _connectionString;

    public PadelClubApiFactory(string containerConnectionString)
    {
        var connectionBuilder = new SqlConnectionStringBuilder(containerConnectionString)
        {
            InitialCatalog = $"PadelClubIntegration_{Guid.NewGuid():N}",
            TrustServerCertificate = true,
            Encrypt = false
        };
        _connectionString = connectionBuilder.ConnectionString;
    }

    public IntegrationSeed Seed { get; private set; } = null!;

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("IntegrationTesting");
        builder.ConfigureAppConfiguration((_, configuration) =>
        {
            configuration.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Database:BootstrapOnStartup"] = "false",
                ["ProviderVerification:Enabled"] = "false",
                ["ConnectionStrings:DefaultConnection"] = _connectionString,
                ["ConnectionStrings:RabbitMq"] = "host=localhost;username=padelclub;password=integration-only",
                ["Authentication:SigningKey"] = "INTEGRATION-ONLY-SIGNING-KEY-AT-LEAST-THIRTY-TWO-CHARACTERS"
            });
        });
        builder.ConfigureTestServices(services =>
        {
            services.RemoveAll<DbContextOptions<PadelClubContext>>();
            services.RemoveAll<PadelClubContext>();
            services.AddDbContext<PadelClubContext>(options => options.UseSqlServer(
                _connectionString,
                sql => sql.UseQuerySplittingBehavior(QuerySplittingBehavior.SplitQuery)));

            // These workers intentionally exercise external delivery/lifecycle
            // paths. They are covered separately and would make HTTP data tests
            // race with a deterministic seed scenario.
            services.RemoveAll<IHostedService>();
        });
    }

    protected override IHost CreateHost(IHostBuilder builder)
    {
        var host = base.CreateHost(builder);
        using var scope = host.Services.CreateScope();
        var database = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
        database.Database.Migrate();
        Seed = IntegrationDatabaseSeeder.Seed(database);
        return host;
    }
}
