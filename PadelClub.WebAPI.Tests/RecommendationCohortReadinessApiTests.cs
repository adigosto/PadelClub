using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using PadelClub.Model.Responses;
using PadelClub.WebAPI.Tests.Infrastructure;
using Xunit;

namespace PadelClub.WebAPI.Tests;

[Collection(SqlServerIntegrationCollection.Name)]
public sealed class RecommendationCohortReadinessApiTests(SqlServerIntegrationFixture fixture)
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private readonly SqlServerIntegrationFixture _fixture = fixture;

    [Fact]
    public async Task Cohort_readiness_is_admin_only_and_returns_aggregate_operational_progress()
    {
        using var anonymousClient = CreateClient();
        Assert.Equal(
            HttpStatusCode.Unauthorized,
            (await anonymousClient.GetAsync("/Operations/recommendations/cohort-readiness")).StatusCode);

        using var playerClient = CreateClient();
        Authorize(playerClient, _fixture.PlayerSession.AccessToken);
        Assert.Equal(
            HttpStatusCode.Forbidden,
            (await playerClient.GetAsync("/Operations/recommendations/cohort-readiness")).StatusCode);

        using var adminClient = CreateClient();
        Authorize(adminClient, _fixture.AdminSession.AccessToken);
        var result = await adminClient.GetAsync("/Operations/recommendations/cohort-readiness");
        Assert.Equal(HttpStatusCode.OK, result.StatusCode);

        var readiness = await result.Content.ReadFromJsonAsync<RecommendationCohortReadinessResponse>(JsonOptions);
        Assert.NotNull(readiness);
        Assert.Equal("Operational", readiness.EvidenceSource);
        Assert.NotEmpty(readiness.Requirements);
        Assert.Contains(
            readiness.Requirements,
            requirement => requirement.Name == "split-specific-evidence" &&
                           requirement.Status == "RequiresEvaluationWindow");
        Assert.NotEmpty(readiness.Limitations);
    }

    private HttpClient CreateClient() => _fixture.Api.CreateClient(new WebApplicationFactoryClientOptions
    {
        BaseAddress = new Uri("https://localhost")
    });

    private static void Authorize(HttpClient client, string accessToken) =>
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
}
