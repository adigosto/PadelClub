namespace PadelClub.Services.Database;

/// <summary>
/// A sticky, server-side user-level random assignment. A user can receive only
/// one arm for a given experiment, preventing cross-arm serving history.
/// </summary>
public sealed class RecommendationExperimentAssignment
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid ExperimentId { get; set; }

    public int UserId { get; set; }

    public RecommendationExperimentVariant Variant { get; set; }

    public DateTime AssignedAtUtc { get; set; } = DateTime.UtcNow;

    public RecommendationExperiment Experiment { get; set; } = null!;

    public User User { get; set; } = null!;

    public ICollection<RecommendationExposure> Exposures { get; set; } =
        new List<RecommendationExposure>();
}
