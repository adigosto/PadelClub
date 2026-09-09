using PadelClub.Services.Database;

namespace PadelClub.WebAPI.Payments;

/// <summary>
/// Acquires recoverable ownership of due refund operations. As with the SQL
/// outbox, a lease deliberately provides at-least-once processing: Stripe
/// reconciliation and an immutable idempotency key make a repeated attempt
/// safe after a worker crash.
/// </summary>
public interface IProviderRefundOperationLeaseService
{
    Task<ProviderRefundOperationLease> ClaimDueAsync(
        int batchSize,
        TimeSpan leaseDuration,
        CancellationToken cancellationToken = default);

    Task<bool> RenewLeaseAsync(
        Guid operationId,
        Guid leaseId,
        TimeSpan leaseDuration,
        CancellationToken cancellationToken = default);

    Task<bool> RecordFailureAsync(
        Guid operationId,
        Guid leaseId,
        DateTime nextAttemptAtUtc,
        string error,
        CancellationToken cancellationToken = default);
}

public sealed record ProviderRefundOperationLease(
    Guid LeaseId,
    IReadOnlyList<ProviderRefundOperation> Operations);
