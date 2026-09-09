using PadelClub.Services.Database;

namespace PadelClub.Services.Outbox;

/// <summary>
/// Coordinates durable, recoverable ownership of pending outbox rows across
/// multiple API replicas.
/// </summary>
public interface IOutboxLeaseService
{
    Task<OutboxLease> ClaimDueAsync(
        int batchSize,
        TimeSpan leaseDuration,
        CancellationToken cancellationToken = default);

    Task<bool> RenewLeaseAsync(
        Guid messageId,
        Guid leaseId,
        TimeSpan leaseDuration,
        CancellationToken cancellationToken = default);

    Task<bool> MarkPublishedAsync(
        Guid messageId,
        Guid leaseId,
        CancellationToken cancellationToken = default);

    Task<bool> RecordFailureAsync(
        Guid messageId,
        Guid leaseId,
        DateTime nextAttemptAtUtc,
        string error,
        CancellationToken cancellationToken = default);
}

public sealed record OutboxLease(Guid LeaseId, IReadOnlyList<OutboxMessage> Messages);
