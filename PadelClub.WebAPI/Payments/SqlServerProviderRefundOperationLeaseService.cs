using Microsoft.EntityFrameworkCore;
using PadelClub.Services.Database;

namespace PadelClub.WebAPI.Payments;

/// <summary>
/// SQL Server lock-protected lease implementation for external refund work.
/// It is separate from the RabbitMQ outbox because payment reconciliation has
/// different completion semantics and must not be published to a broker.
/// </summary>
public sealed class SqlServerProviderRefundOperationLeaseService(PadelClubContext database)
    : IProviderRefundOperationLeaseService
{
    public async Task<ProviderRefundOperationLease> ClaimDueAsync(
        int batchSize,
        TimeSpan leaseDuration,
        CancellationToken cancellationToken = default)
    {
        ValidateBatchAndDuration(batchSize, leaseDuration);
        EnsureSqlServer();

        var leaseId = Guid.NewGuid();
        var leaseSeconds = checked((int)Math.Ceiling(leaseDuration.TotalSeconds));
        await using var transaction = await database.Database.BeginTransactionAsync(
            System.Data.IsolationLevel.ReadCommitted,
            cancellationToken);
        await database.Database.ExecuteSqlInterpolatedAsync($"""
            ;WITH [DueOperations] AS
            (
                SELECT TOP ({batchSize}) *
                FROM [ProviderRefundOperations] WITH (UPDLOCK, READPAST, ROWLOCK, READCOMMITTEDLOCK)
                WHERE [Status] = {ProviderRefundOperationStatuses.Pending}
                  AND [NextAttemptAtUtc] <= SYSUTCDATETIME()
                  AND ([LeaseExpiresAtUtc] IS NULL OR [LeaseExpiresAtUtc] <= SYSUTCDATETIME())
                ORDER BY [CreatedAtUtc], [Id]
            )
            UPDATE [DueOperations]
            SET [LeaseId] = {leaseId},
                [LeaseExpiresAtUtc] = DATEADD(second, {leaseSeconds}, SYSUTCDATETIME()),
                [LastAttemptAtUtc] = SYSUTCDATETIME();
            """, cancellationToken);

        var operations = await database.ProviderRefundOperations
            .AsNoTracking()
            .Where(operation => operation.Status == ProviderRefundOperationStatuses.Pending && operation.LeaseId == leaseId)
            .OrderBy(operation => operation.CreatedAtUtc)
            .ThenBy(operation => operation.Id)
            .ToListAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return new ProviderRefundOperationLease(leaseId, operations);
    }

    public async Task<bool> RenewLeaseAsync(
        Guid operationId,
        Guid leaseId,
        TimeSpan leaseDuration,
        CancellationToken cancellationToken = default)
    {
        ValidateDuration(leaseDuration);
        EnsureSqlServer();
        var leaseSeconds = checked((int)Math.Ceiling(leaseDuration.TotalSeconds));
        var changed = await database.Database.ExecuteSqlInterpolatedAsync($"""
            UPDATE [ProviderRefundOperations]
            SET [LeaseExpiresAtUtc] = DATEADD(second, {leaseSeconds}, SYSUTCDATETIME()),
                [LastAttemptAtUtc] = SYSUTCDATETIME()
            WHERE [Id] = {operationId}
              AND [LeaseId] = {leaseId}
              AND [Status] = {ProviderRefundOperationStatuses.Pending}
              AND [LeaseExpiresAtUtc] > SYSUTCDATETIME();
            """, cancellationToken);
        return changed == 1;
    }

    public async Task<bool> RecordFailureAsync(
        Guid operationId,
        Guid leaseId,
        DateTime nextAttemptAtUtc,
        string error,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(error);
        EnsureSqlServer();
        var changed = await database.Database.ExecuteSqlInterpolatedAsync($"""
            UPDATE [ProviderRefundOperations]
            SET [AttemptCount] = [AttemptCount] + 1,
                [NextAttemptAtUtc] = {nextAttemptAtUtc},
                [LastError] = {TrimError(error)},
                [LeaseId] = NULL,
                [LeaseExpiresAtUtc] = NULL
            WHERE [Id] = {operationId}
              AND [LeaseId] = {leaseId}
              AND [Status] = {ProviderRefundOperationStatuses.Pending}
              AND [LeaseExpiresAtUtc] > SYSUTCDATETIME();
            """, cancellationToken);
        return changed == 1;
    }

    private void EnsureSqlServer()
    {
        if (!database.Database.IsSqlServer())
            throw new NotSupportedException("Provider refund leasing requires SQL Server row-lock semantics.");
    }

    private static void ValidateBatchAndDuration(int batchSize, TimeSpan leaseDuration)
    {
        if (batchSize is < 1 or > 100)
            throw new ArgumentOutOfRangeException(nameof(batchSize), "Batch size must be between 1 and 100.");
        ValidateDuration(leaseDuration);
    }

    private static void ValidateDuration(TimeSpan leaseDuration)
    {
        if (leaseDuration <= TimeSpan.Zero || leaseDuration > TimeSpan.FromHours(1))
            throw new ArgumentOutOfRangeException(nameof(leaseDuration), "Lease duration must be greater than zero and at most one hour.");
    }

    private static string TrimError(string error) => error.Length <= 2_000 ? error : error[..2_000];
}
