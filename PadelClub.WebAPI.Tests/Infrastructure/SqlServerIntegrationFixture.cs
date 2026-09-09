using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using Testcontainers.MsSql;
using Xunit;

namespace PadelClub.WebAPI.Tests.Infrastructure;

[CollectionDefinition(Name, DisableParallelization = true)]
public sealed class SqlServerIntegrationCollection : ICollectionFixture<SqlServerIntegrationFixture>
{
    public const string Name = "SQL Server HTTP integration";
}

/// <summary>
/// Runs the HTTP integration slice against an ephemeral SQL Server instance.
/// The image is pinned by digest so local and CI test runs use the same server
/// image instead of an unpinned rolling tag.
/// </summary>
public sealed class SqlServerIntegrationFixture : IAsyncLifetime
{
    private const string SqlServerImage =
        "mcr.microsoft.com/mssql/server@sha256:d01cc45e6b920eff17abc60295b8748821e09b678f0fcf54959ef37406b80203";

    private readonly MsSqlContainer _container = new MsSqlBuilder(SqlServerImage)
        .WithDatabase("master")
        .WithPassword("PadelClubIntegration!2026")
        .Build();

    public PadelClubApiFactory Api { get; private set; } = null!;
    public AuthResponse AdminSession { get; private set; } = null!;
    public AuthResponse PlayerSession { get; private set; } = null!;

    public async Task InitializeAsync()
    {
        await _container.StartAsync();
        Api = new PadelClubApiFactory(_container.GetConnectionString());

        // Creating a client starts the TestServer, applies the real migrations,
        // and inserts the deterministic scenario before any test executes.
        using var client = Api.CreateClient(new WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri("https://localhost")
        });
        PlayerSession = await LoginAsync(client, Api.Seed.PlayerUsername);
        AdminSession = await LoginAsync(client, Api.Seed.AdminUsername);
    }

    public async Task DisposeAsync()
    {
        Api?.Dispose();
        await _container.DisposeAsync();
    }

    private async Task<AuthResponse> LoginAsync(HttpClient client, string username)
    {
        var response = await client.PostAsJsonAsync("/Users/login", new UserLoginRequest
        {
            Username = username,
            Password = Api.Seed.Password
        });
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<AuthResponse>(new JsonSerializerOptions(JsonSerializerDefaults.Web)))!;
    }

}
