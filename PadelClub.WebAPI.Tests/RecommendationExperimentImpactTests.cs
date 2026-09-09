using Microsoft.EntityFrameworkCore;
using PadelClub.Services.Database;
using PadelClub.Services.Recommendations;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public sealed class RecommendationExperimentImpactTests
{
    [Fact]
    public async Task Collecting_experiment_exposes_progress_but_never_fabricates_zero_lift()
    {
        await using var db = CreateDb();
        var now = DateTime.UtcNow;
        var experiment = Experiment(Guid.NewGuid(), status: RecommendationExperimentStatuses.Running, now);
        db.Users.Add(User(1));
        db.RecommendationExperiments.Add(experiment);
        await db.SaveChangesAsync();

        var report = await new RecommendationExperimentService(db).GetImpactAsync(experiment.Id);

        Assert.NotNull(report);
        Assert.Equal("Collecting", report!.EvidenceTier);
        Assert.False(report.IsCausalEstimateAvailable);
        Assert.Null(report.AbsoluteLift);
        Assert.Null(report.RelativeLift);
        Assert.Null(report.AbsoluteLiftConfidenceIntervalLower);
        Assert.Contains(report.UnmetRequirements, requirement => requirement.Name == "experiment-closed");
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task Mature_randomized_operational_arms_require_actual_serving_coverage(bool spreadAcrossDays)
    {
        await using var db = CreateDb();
        var now = DateTime.UtcNow;
        var experiment = Experiment(Guid.NewGuid(), RecommendationExperimentStatuses.Closed, now);
        var product = new Product
        {
            Id = 1,
            Name = "Experiment product",
            Description = "Experiment product",
            Price = 10m,
            StockQuantity = 500,
            ProductState = "ActiveProductState",
            IsActive = true
        };
        db.RecommendationExperiments.Add(experiment);
        db.Products.Add(product);

        AddArm(db, experiment, product, RecommendationExperimentVariant.Control, firstUserId: 1, outcomeUsers: 10, now, spreadAcrossDays);
        AddArm(db, experiment, product, RecommendationExperimentVariant.Treatment, firstUserId: 101, outcomeUsers: 25, now, spreadAcrossDays);
        // A pre-experiment exposure has no assignment and can never become a
        // randomized result merely because the report is later added.
        var historicalUser = User(300);
        db.Users.Add(historicalUser);
        db.RecommendationExposures.Add(new RecommendationExposure
        {
            UserId = historicalUser.Id,
            User = historicalUser,
            ProductId = product.Id,
            Product = product,
            AlgorithmVersion = ItemBasedCollaborativeRanker.Version,
            Strategy = "collaborative-filtering",
            Rank = 1,
            ServedAtUtc = now.AddDays(-22),
            TelemetrySource = RecommendationTelemetrySource.OperationalCustomer,
            ClickedAtUtc = now.AddDays(-22).AddMinutes(1)
        });
        await db.SaveChangesAsync();

        var report = await new RecommendationExperimentService(db).GetImpactAsync(experiment.Id);

        Assert.NotNull(report);
        if (!spreadAcrossDays)
        {
            Assert.False(report!.IsCausalEstimateAvailable);
            Assert.Null(report.AbsoluteLift);
            Assert.Contains(report.UnmetRequirements, item => item.Name == "observation-days");
            return;
        }
        Assert.Equal("CausalEstimate", report!.EvidenceTier);
        Assert.True(report.IsCausalEstimateAvailable);
        Assert.Equal(50, report.Control.AssignedUsers);
        Assert.Equal(50, report.Treatment.AssignedUsers);
        Assert.Equal(50, report.Control.MaturedServedUsers);
        Assert.Equal(50, report.Treatment.MaturedServedUsers);
        Assert.Equal(100, report.Control.MaturedExposures);
        Assert.Equal(100, report.Treatment.MaturedExposures);
        Assert.Equal(10, report.Control.UsersWithAttributedCheckout);
        Assert.Equal(25, report.Treatment.UsersWithAttributedCheckout);
        Assert.Equal(0.20d, report.Control.PrimaryOutcomeRate!.Value, precision: 12);
        Assert.Equal(0.50d, report.Treatment.PrimaryOutcomeRate!.Value, precision: 12);
        Assert.Equal(0.30d, report.AbsoluteLift!.Value, precision: 12);
        Assert.NotNull(report.AbsoluteLiftConfidenceIntervalLower);
        Assert.NotNull(report.AbsoluteLiftConfidenceIntervalUpper);
        Assert.Empty(report.UnmetRequirements);

        // Failed/empty serving must not remove a randomized user from the
        // denominator. Unchanged source facts must hash identically on rerun.
        var unservedUser = User(400);
        db.Users.Add(unservedUser);
        db.RecommendationExperimentAssignments.Add(new RecommendationExperimentAssignment
        {
            ExperimentId = experiment.Id, UserId = unservedUser.Id,
            Variant = RecommendationExperimentVariant.Treatment,
            AssignedAtUtc = now.AddDays(-23)
        });
        await db.SaveChangesAsync();
        var service = new RecommendationExperimentService(db);
        var first = await service.CreateAnalysisRunAsync(1, experiment.Id);
        var second = await service.CreateAnalysisRunAsync(1, experiment.Id);
        Assert.Equal(51, first!.Report.Treatment.AssignedUsers);
        Assert.Equal(25d / 51d, first.Report.Treatment.PrimaryOutcomeRate!.Value, 12);
        Assert.Equal(first.InputFingerprintSha256, second!.InputFingerprintSha256);
    }

    private static void AddArm(
        PadelClubContext db,
        RecommendationExperiment experiment,
        Product product,
        RecommendationExperimentVariant variant,
        int firstUserId,
        int outcomeUsers,
        DateTime now,
        bool spreadAcrossDays)
    {
        for (var offset = 0; offset < 50; offset++)
        {
            var user = User(firstUserId + offset);
            var assignment = new RecommendationExperimentAssignment
            {
                ExperimentId = experiment.Id,
                Experiment = experiment,
                UserId = user.Id,
                User = user,
                Variant = variant,
                AssignedAtUtc = now.AddDays(-23)
            };
            db.Users.Add(user);
            db.RecommendationExperimentAssignments.Add(assignment);
            for (var exposureIndex = 0; exposureIndex < 2; exposureIndex++)
            {
                var servedAt = now.AddDays(-23 + (spreadAcrossDays ? exposureIndex * 14 : 0))
                    .AddMinutes(offset * 3 + exposureIndex);
                var exposure = new RecommendationExposure
                {
                    UserId = user.Id,
                    User = user,
                    ProductId = product.Id,
                    Product = product,
                    ExperimentAssignmentId = assignment.Id,
                    ExperimentAssignment = assignment,
                    AlgorithmVersion = variant == RecommendationExperimentVariant.Control
                        ? PopularityRecommendationRanker.Version
                        : ItemBasedCollaborativeRanker.Version,
                    Strategy = variant == RecommendationExperimentVariant.Control
                        ? RecommendationExperimentPolicy.ControlStrategy
                        : RecommendationExperimentPolicy.TreatmentStrategy,
                    Rank = exposureIndex + 1,
                    ServedAtUtc = servedAt,
                    TelemetrySource = RecommendationTelemetrySource.OperationalCustomer,
                    ClickedAtUtc = servedAt.AddMinutes(1)
                };
                if (offset < outcomeUsers && exposureIndex == 0)
                {
                    var order = new Order
                    {
                        UserId = user.Id,
                        User = user,
                        OrderNumber = $"EXP-{variant}-{user.Id}",
                        Status = "Delivered",
                        RecipientName = "Experiment Player",
                        PhoneNumber = "000000000",
                        ShippingAddress = "Test street 1",
                        City = "Sarajevo",
                        PostalCode = "71000",
                        TotalAmount = 10m,
                        SubtotalAmount = 10m,
                        Origin = OrderOrigin.CustomerCheckout,
                        IsSeededForDemo = false,
                        CreatedAt = servedAt.AddMinutes(2),
                        DeliveredAt = servedAt.AddDays(1)
                    };
                    db.Orders.Add(order);
                    exposure.PurchasedOrder = order;
                    exposure.PurchasedOrderId = order.Id;
                    exposure.PurchasedAtUtc = servedAt.AddMinutes(2);
                }
                db.RecommendationExposures.Add(exposure);
            }
        }
    }

    private static RecommendationExperiment Experiment(Guid id, string status, DateTime now) => new()
    {
        Id = id,
        ExperimentKey = RecommendationExperimentPolicy.ExperimentKey,
        Status = status,
        CreatedByUserId = 1,
        CreatedAtUtc = now.AddDays(-25),
        StartedAtUtc = now.AddDays(-24),
        ClosedAtUtc = status == RecommendationExperimentStatuses.Closed ? now.AddDays(-8) : null,
        Protocol = RecommendationExperimentPolicy.Protocol,
        TreatmentAlgorithmVersion = ItemBasedCollaborativeRanker.Version,
        ControlAlgorithmVersion = PopularityRecommendationRanker.Version,
        TreatmentStrategy = RecommendationExperimentPolicy.TreatmentStrategy,
        ControlStrategy = RecommendationExperimentPolicy.ControlStrategy,
        TreatmentAllocationPercent = 50,
        RecommendationLimit = RecommendationExperimentPolicy.RecommendationLimit,
        AttributionWindowDays = RecommendationExperimentPolicy.AttributionWindowDays,
        ReturnMaturityDays = RecommendationExperimentPolicy.ReturnMaturityDays,
        ConfigurationSha256 = new string('a', 64)
    };

    private static User User(int id) => new()
    {
        Id = id,
        Username = $"experiment-{id}",
        Email = $"experiment-{id}@example.test",
        FirstName = "Experiment",
        LastName = "Player",
        PasswordHash = "test-hash",
        PasswordSalt = "test-salt",
        IsActive = true
    };

    private static PadelClubContext CreateDb()
    {
        var options = new DbContextOptionsBuilder<PadelClubContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;
        return new PadelClubContext(options);
    }
}
