namespace PadelClub.Services.Database;

/// <summary>
/// Immutable pre-registered definition of a prospective recommendation
/// experiment. There is no update path: creation records the protocol and a
/// later start/close changes only its lifecycle state.
/// </summary>
public sealed class RecommendationExperiment
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public string ExperimentKey { get; set; } = string.Empty;

    public string Status { get; set; } = "Draft";

    public int CreatedByUserId { get; set; }

    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;

    public DateTime? StartedAtUtc { get; set; }

    public DateTime? ClosedAtUtc { get; set; }

    public string Protocol { get; set; } = string.Empty;

    public string TreatmentAlgorithmVersion { get; set; } = string.Empty;

    public string ControlAlgorithmVersion { get; set; } = string.Empty;

    public string TreatmentStrategy { get; set; } = string.Empty;

    public string ControlStrategy { get; set; } = string.Empty;

    public int TreatmentAllocationPercent { get; set; }

    public int RecommendationLimit { get; set; }

    public int AttributionWindowDays { get; set; }

    public int ReturnMaturityDays { get; set; }

    public string ConfigurationSha256 { get; set; } = string.Empty;

    public User CreatedByUser { get; set; } = null!;

    public ICollection<RecommendationExperimentAssignment> Assignments { get; set; } =
        new List<RecommendationExperimentAssignment>();

    public ICollection<RecommendationExperimentAnalysisRun> AnalysisRuns { get; set; } =
        new List<RecommendationExperimentAnalysisRun>();
}
