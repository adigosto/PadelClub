namespace PadelClub.Services.Database;

/// <summary>
/// Append-only aggregate snapshot of a prospective experiment analysis. It
/// keeps reproducible evidence without storing participant-level tuples.
/// </summary>
public sealed class RecommendationExperimentAnalysisRun
{
    public long Id { get; set; }

    public Guid RunId { get; set; } = Guid.NewGuid();

    public Guid ExperimentId { get; set; }

    public int ExecutedByUserId { get; set; }

    public DateTime ExecutedAtUtc { get; set; } = DateTime.UtcNow;

    public string EvidenceTier { get; set; } = "Collecting";

    public string Protocol { get; set; } = string.Empty;

    public string ConfigurationSha256 { get; set; } = string.Empty;

    public string InputFingerprintSha256 { get; set; } = string.Empty;

    public string ReportJson { get; set; } = string.Empty;

    public RecommendationExperiment Experiment { get; set; } = null!;

    public User ExecutedByUser { get; set; } = null!;
}
