namespace PadelClub.Services.Database;

/// <summary>
/// Durable at-least-once publication record. A business change and its event
/// are saved in one SQL transaction; the hosted publisher retries broker
/// delivery after the transaction commits.
/// </summary>
public sealed class OutboxMessage
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public string Type { get; set; } = string.Empty;

    public string Payload { get; set; } = string.Empty;

    public DateTime OccurredAtUtc { get; set; } = DateTime.UtcNow;

    public DateTime? PublishedAtUtc { get; set; }

    public int AttemptCount { get; set; }

    public DateTime NextAttemptAtUtc { get; set; } = DateTime.UtcNow;

    public string? LastError { get; set; }

    /// <summary>
    /// Identifies the publisher replica currently responsible for this row.
    /// A lease is intentionally recoverable after <see cref="LeaseExpiresAtUtc"/>
    /// so a crashed replica cannot strand a committed event.
    /// </summary>
    public Guid? LeaseId { get; set; }

    public DateTime? LeaseExpiresAtUtc { get; set; }
}
