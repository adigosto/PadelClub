namespace PadelClub.Services.Database;

/// <summary>
/// Durable, provider-facing refund intent. The operation is created and
/// committed before a background worker contacts a payment provider, allowing
/// retry and reconciliation after process or database failures.
/// </summary>
public sealed class ProviderRefundOperation
{
    /// <summary>Stable operation identity used in provider metadata.</summary>
    public Guid Id { get; set; } = Guid.NewGuid();

    public int PaymentId { get; set; }

    /// <summary>
    /// Present for a merchandise-return refund. A filtered unique index allows
    /// at most one durable provider refund operation for each return request.
    /// </summary>
    public int? ReturnRequestId { get; set; }

    public int RequestedByUserId { get; set; }

    public string Provider { get; set; } = string.Empty;

    public string Currency { get; set; } = string.Empty;

    /// <summary>Immutable snapshot of the provider payment-intent identifier.</summary>
    public string PaymentIntentId { get; set; } = string.Empty;

    public decimal Amount { get; set; }

    /// <summary>
    /// The payment's expected cumulative refunded total after this operation
    /// succeeds. It prevents a late Stripe charge webhook from making local
    /// settlement add the same refund amount twice.
    /// </summary>
    public decimal ExpectedRefundedAmount { get; set; }

    public string Reason { get; set; } = string.Empty;

    /// <summary>Stable provider idempotency key, never derived from mutable payment totals.</summary>
    public string IdempotencyKey { get; set; } = string.Empty;

    /// <summary>Lifecycle string, for example Pending, Processing, Succeeded, Retry, or Failed.</summary>
    public string Status { get; set; } = "Pending";

    public string? ProviderRefundId { get; set; }

    public int AttemptCount { get; set; }

    public DateTime NextAttemptAtUtc { get; set; } = DateTime.UtcNow;

    public DateTime? LastAttemptAtUtc { get; set; }

    public string? LastError { get; set; }

    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;

    public DateTime? ProviderAcceptedAtUtc { get; set; }

    public DateTime? CompletedAtUtc { get; set; }

    public Guid? LeaseId { get; set; }

    public DateTime? LeaseExpiresAtUtc { get; set; }

    public Payment Payment { get; set; } = null!;

    public ReturnRequest? ReturnRequest { get; set; }

    public User RequestedByUser { get; set; } = null!;
}
