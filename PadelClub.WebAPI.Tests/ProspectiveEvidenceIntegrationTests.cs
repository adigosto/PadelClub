using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using PadelClub.Model.Responses;
using PadelClub.Services.Database;
using PadelClub.WebAPI.Tests.Infrastructure;
using Xunit;

namespace PadelClub.WebAPI.Tests;

[Collection(SqlServerIntegrationCollection.Name)]
public sealed class ProspectiveEvidenceIntegrationTests(SqlServerIntegrationFixture fixture)
{
    [Fact]
    public async Task Consent_and_experiment_lifecycle_persist_without_turning_test_traffic_into_customer_evidence()
    {
        using var player = Client(fixture.PlayerSession.AccessToken);
        using var admin = Client(fixture.AdminSession.AccessToken);
        const string experiments = "/Operations/recommendations/experiments";
        Assert.Equal(HttpStatusCode.Forbidden, (await player.PostAsync(experiments, null)).StatusCode);

        var consent = await player.PutAsJsonAsync("/Recommendations/analytics-consent", new { isGranted = true });
        consent.EnsureSuccessStatusCode();
        Assert.True((await player.GetFromJsonAsync<RecommendationAnalyticsConsentResponse>("/Recommendations/analytics-consent"))!.IsGranted);

        var created = await admin.PostAsync(experiments, null);
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var experiment = (await created.Content.ReadFromJsonAsync<RecommendationExperimentResponse>())!;
        (await admin.PostAsync($"{experiments}/{experiment.Id}/start", null)).EnsureSuccessStatusCode();
        (await player.GetAsync("/Recommendations/products?limit=6")).EnsureSuccessStatusCode();
        (await admin.PostAsync($"{experiments}/{experiment.Id}/close", null)).EnsureSuccessStatusCode();

        var saved = await admin.PostAsync($"{experiments}/{experiment.Id}/analysis-runs", null);
        Assert.Equal(HttpStatusCode.Created, saved.StatusCode);
        var run = (await saved.Content.ReadFromJsonAsync<RecommendationExperimentAnalysisRunResponse>())!;
        var latest = await admin.GetFromJsonAsync<RecommendationExperimentAnalysisRunResponse>($"{experiments}/{experiment.Id}/analysis-runs/latest");
        Assert.Equal(run.RunId, latest!.RunId);
        Assert.Equal("Collecting", latest.EvidenceTier);
        Assert.Null(latest.Report.AbsoluteLift);
        Assert.Equal(0, latest.Report.Control.AssignedUsers + latest.Report.Treatment.AssignedUsers);

        await using var scope = fixture.Api.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
        Assert.True(await db.RecommendationExperimentAnalysisRuns.AnyAsync(item => item.RunId == run.RunId));
        Assert.False(await db.RecommendationExperimentAssignments.AnyAsync(item => item.ExperimentId == experiment.Id));
        (await player.PutAsJsonAsync("/Recommendations/analytics-consent", new { isGranted = false })).EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task Provider_rehearsal_is_admin_only_and_disabled_without_creating_evidence()
    {
        using var player = Client(fixture.PlayerSession.AccessToken);
        using var admin = Client(fixture.AdminSession.AccessToken);
        const string route = "/Operations/provider-verification";
        Assert.Equal(HttpStatusCode.Forbidden, (await player.GetAsync(route)).StatusCode);
        foreach (var provider in new[] { "stripe", "smtp", "firebase" })
        {
            var response = await admin.PostAsJsonAsync($"{route}/{provider}", new { confirmExternalCall = true });
            Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        }
        Assert.Empty((await admin.GetFromJsonAsync<List<ProviderVerificationAttemptResponse>>(route))!);
    }

    private HttpClient Client(string token)
    {
        var client = fixture.Api.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return client;
    }
}
