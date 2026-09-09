namespace PadelClub.Services.Database;

/// <summary>
/// A durable record of one deliberately authorised external-provider
/// rehearsal. The row is written before the outbound call so a process crash
/// remains visible as <c>Started</c>, never as invented success. It contains
/// no credential, recipient, device identifier, provider object identifier,
/// or raw provider error.
/// </summary>
public sealed class ProviderVerificationAttempt
{
    public long Id { get; set; }

    public Guid CorrelationId { get; set; } = Guid.NewGuid();

    public int RequestedByUserId { get; set; }

    public string Provider { get; set; } = string.Empty;

    public string VerificationKind { get; set; } = string.Empty;

    /// <summary>Started, Succeeded, or Failed.</summary>
    public string Status { get; set; } = ProviderVerificationAttemptStatuses.Started;

    /// <summary>
    /// A small, safe classification such as <c>SmtpAccepted</c> or
    /// <c>TransportFailure</c>. Raw exceptions are intentionally excluded.
    /// </summary>
    public string OutcomeCategory { get; set; } = ProviderVerificationOutcomeCategories.Started;

    public DateTime StartedAtUtc { get; set; } = DateTime.UtcNow;

    public DateTime? CompletedAtUtc { get; set; }

    public User RequestedByUser { get; set; } = null!;
}

public static class ProviderVerificationAttemptStatuses
{
    public const string Started = "Started";
    public const string Succeeded = "Succeeded";
    public const string Failed = "Failed";
}

public static class ProviderVerificationOutcomeCategories
{
    public const string Started = "Started";
    public const string StripeTestReadAccepted = "StripeTestReadAccepted";
    public const string SmtpAccepted = "SmtpAccepted";
    public const string FirebaseAccepted = "FirebaseAccepted";
    public const string ProviderRejected = "ProviderRejected";
    public const string TransportFailure = "TransportFailure";
    public const string UnexpectedFailure = "UnexpectedFailure";
}
