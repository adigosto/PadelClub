using Microsoft.EntityFrameworkCore;
using PadelClub.Services.Database;
using PadelClub.Services.Recommendations;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public sealed class RecommendationExperimentServiceTests
{
    [Fact]
    public async Task Only_consented_operational_players_receive_a_sticky_server_assignment()
    {
        await using var db = CreateDb();
        db.Users.Add(User(1, "experiment-player"));
        await db.SaveChangesAsync();
        var service = new RecommendationExperimentService(db, new FixedRandomizer(treatment: true));

        var draft = await service.CreateAsync(1);
        await service.StartAsync(draft.Id);

        Assert.Null(await service.GetActiveAssignmentAsync(
            1,
            RecommendationTelemetrySource.DevelopmentDemo,
            RecommendationExperimentPolicy.RecommendationLimit));
        Assert.Null(await service.GetActiveAssignmentAsync(
            1,
            RecommendationTelemetrySource.OperationalCustomer,
            RecommendationExperimentPolicy.RecommendationLimit));

        var consent = await service.SetConsentAsync(1, isGranted: true);
        Assert.True(consent.IsGranted);
        var first = await service.GetActiveAssignmentAsync(
            1,
            RecommendationTelemetrySource.OperationalCustomer,
            RecommendationExperimentPolicy.RecommendationLimit);
        var second = await service.GetActiveAssignmentAsync(
            1,
            RecommendationTelemetrySource.OperationalCustomer,
            RecommendationExperimentPolicy.RecommendationLimit);

        Assert.NotNull(first);
        Assert.Equal(RecommendationExperimentVariant.Treatment, first!.Variant);
        Assert.Equal(first.AssignmentId, second!.AssignmentId);
        Assert.Equal(RecommendationExperimentPolicy.TreatmentStrategy, first.Strategy);
        Assert.Equal(ItemBasedCollaborativeRanker.Version, first.AlgorithmVersion);
        Assert.Single(db.RecommendationExperimentAssignments);

        var revoked = await service.SetConsentAsync(1, isGranted: false);
        Assert.False(revoked.IsGranted);
        Assert.Null(await service.GetActiveAssignmentAsync(
            1,
            RecommendationTelemetrySource.OperationalCustomer,
            RecommendationExperimentPolicy.RecommendationLimit));
    }

    [Fact]
    public async Task Experiment_protocol_cannot_be_mutated_after_registration()
    {
        await using var db = CreateDb();
        db.Users.Add(User(1, "experiment-admin"));
        await db.SaveChangesAsync();
        var service = new RecommendationExperimentService(db, new FixedRandomizer(treatment: false));
        var created = await service.CreateAsync(1);
        var experiment = await db.RecommendationExperiments.SingleAsync(x => x.Id == created.Id);

        experiment.ControlStrategy = "tampered-control";

        var exception = await Assert.ThrowsAsync<InvalidOperationException>(() => db.SaveChangesAsync());
        Assert.Contains("protocol is immutable", exception.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Analysis_run_is_append_only_aggregate_evidence()
    {
        await using var db = CreateDb();
        db.Users.Add(User(1, "experiment-analyst"));
        await db.SaveChangesAsync();
        var service = new RecommendationExperimentService(db, new FixedRandomizer(treatment: false));
        var created = await service.CreateAsync(1);

        var run = await service.CreateAnalysisRunAsync(1, created.Id);

        Assert.NotNull(run);
        var persisted = await db.RecommendationExperimentAnalysisRuns.SingleAsync();
        persisted.ReportJson = "{}";
        var exception = await Assert.ThrowsAsync<InvalidOperationException>(() => db.SaveChangesAsync());
        Assert.Contains("analysis evidence is append-only", exception.Message, StringComparison.OrdinalIgnoreCase);
    }

    private static PadelClubContext CreateDb()
    {
        var options = new DbContextOptionsBuilder<PadelClubContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;
        return new PadelClubContext(options);
    }

    private static User User(int id, string username) => new()
    {
        Id = id,
        Username = username,
        Email = $"{username}@example.test",
        FirstName = "Experiment",
        LastName = "Player",
        PasswordHash = "test-hash",
        PasswordSalt = "test-salt",
        IsActive = true
    };

    private sealed class FixedRandomizer(bool treatment) : IRecommendationExperimentRandomizer
    {
        public bool NextTreatmentPercent(int treatmentPercent) => treatment;
    }
}
