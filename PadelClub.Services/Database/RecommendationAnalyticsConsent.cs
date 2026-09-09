namespace PadelClub.Services.Database;

/// <summary>
/// The current, explicit choice to permit prospective recommendation
/// experiment telemetry. It is intentionally separate from notification
/// preferences: receiving email/push messages is not consent to analytics.
/// </summary>
public sealed class RecommendationAnalyticsConsent
{
    public int UserId { get; set; }

    public DateTime? GrantedAtUtc { get; set; }

    public DateTime? RevokedAtUtc { get; set; }

    public string PolicyVersion { get; set; } = string.Empty;

    public DateTime UpdatedAtUtc { get; set; } = DateTime.UtcNow;

    public User User { get; set; } = null!;

    public bool IsActive => GrantedAtUtc is not null && RevokedAtUtc is null;
}
