namespace PadelClub.Services.Database;

/// <summary>
/// Immutable, aggregate-only evidence captured when an administrator records
/// a recommendation evaluation. It never stores raw customer interaction
/// tuples; the input is represented by a deterministic SHA-256 fingerprint.
/// </summary>
public sealed class RecommendationEvaluationRun
{
    public long Id { get; set; }

    public Guid RunId { get; set; } = Guid.NewGuid();

    public int ExecutedByUserId { get; set; }

    public DateTime ExecutedAtUtc { get; set; } = DateTime.UtcNow;

    public string EvidenceSource { get; set; } = "Operational";

    public string EvidenceTier { get; set; } = "Unavailable";

    public string Protocol { get; set; } = string.Empty;

    public string AlgorithmVersion { get; set; } = string.Empty;

    public string ConfigurationSha256 { get; set; } = string.Empty;

    public string InputFingerprintSha256 { get; set; } = string.Empty;

    public DateTime CutoffUtc { get; set; }

    public DateTime EndUtc { get; set; }

    public int K { get; set; }

    public int ReturnMaturityDays { get; set; }

    public int EligibleDeliveredOrders { get; set; }

    public int TrainingSignals { get; set; }

    public int HoldoutSignals { get; set; }

    public int CandidateProducts { get; set; }

    public int EvaluatedUsers { get; set; }

    /// <summary>
    /// A serialized <c>RecommendationEvaluationResponse</c> containing only
    /// aggregate metrics, gates, and limitations. It is a point-in-time report
    /// even if later returns or privacy deletions alter the live cohort.
    /// </summary>
    public string ReportJson { get; set; } = string.Empty;

    public User ExecutedByUser { get; set; } = null!;
}
