using Microsoft.EntityFrameworkCore;
using PadelClub.Services.Database;

namespace PadelClub.Services.Outbox;

/// <summary>
/// SQL Server implementation of an outbox lease. Claiming uses one atomic
/// UPDATE over lock-protected candidates, so two publisher replicas cannot
/// intentionally publish the same pending row at the same time. A lease can
/// still expire after a process crash; consumers must therefore remain
/// idempotent because delivery is at least once, not exactly once.
/// </summary>
public sealed class SqlServerOutboxLeaseService(PadelClubContext database) : IOutboxLeaseService
{
    public async Task<OutboxLease> ClaimDueAsync(
        int batchSize,
        TimeSpan leaseDuration,
        CancellationToken cancellationToken = default)
    {
        ValidateBatchAndDuration(batchSize, leaseDuration);
        EnsureSqlServer();

        var leaseId = Guid.NewGuid();
        var leaseSeconds = checked((int)Math.Ceiling(leaseDuration.TotalSeconds));

        // The explicit transaction forces a locking read-committed session even
        // when the database enables READ_COMMITTED_SNAPSHOT. READPAST can then
        // safely skip a row being claimed by another API replica; UPDLOCK keeps
        // selection and lease assignment one ownership operation. Database time
        // avoids replica clock skew.
        await using var transaction = await database.Database.BeginTransactionAsync(
            System.Data.IsolationLevel.ReadCommitted,
            cancellationToken);
        await database.Database.ExecuteSqlInterpolatedAsync($"""
            ;WITH [DueMessages] AS
            (
                SELECT TOP ({batchSize}) *
                FROM [OutboxMessages] WITH (UPDLOCK, READPAST, ROWLOCK, READCOMMITTEDLOCK)
                WHERE [PublishedAtUtc] IS NULL
                  AND [NextAttemptAtUtc] <= SYSUTCDATETIME()
                  AND ([LeaseExpiresAtUtc] IS NULL OR [LeaseExpiresAtUtc] <= SYSUTCDATETIME())
                ORDER BY [OccurredAtUtc], [Id]
            )
            UPDATE [DueMessages]
            SET [LeaseId] = {leaseId},
                [LeaseExpiresAtUtc] = DATEADD(second, {leaseSeconds}, SYSUTCDATETIME());
            """, cancellationToken);

        var messages = await database.OutboxMessages
            .AsNoTracking()
            .Where(message => message.PublishedAtUtc == null && message.LeaseId == leaseId)
            .OrderBy(message => message.OccurredAtUtc)
            .ThenBy(message => message.Id)
            .ToListAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        return new OutboxLease(leaseId, messages);
    }

    public async Task<bool> RenewLeaseAsync(
        Guid messageId,
        Guid leaseId,
        TimeSpan leaseDuration,
        CancellationToken cancellationToken = default)
    {
        ValidateDuration(leaseDuration);
        EnsureSqlServer();
        var leaseSeconds = checked((int)Math.Ceiling(leaseDuration.TotalSeconds));

        var changed = await database.Database.ExecuteSqlInterpolatedAsync($"""
            UPDATE [OutboxMessages]
            SET [LeaseExpiresAtUtc] = DATEADD(second, {leaseSeconds}, SYSUTCDATETIME())
            WHERE [Id] = {messageId}
              AND [LeaseId] = {leaseId}
              AND [PublishedAtUtc] IS NULL
              AND [LeaseExpiresAtUtc] > SYSUTCDATETIME();
            """, cancellationToken);

        return changed == 1;
    }

    public async Task<bool> MarkPublishedAsync(
        Guid messageId,
        Guid leaseId,
        CancellationToken cancellationToken = default)
    {
        EnsureSqlServer();
        var changed = await database.Database.ExecuteSqlInterpolatedAsync($"""
            UPDATE [OutboxMessages]
            SET [AttemptCount] = [AttemptCount] + 1,
                [PublishedAtUtc] = SYSUTCDATETIME(),
                [LastError] = NULL,
                [LeaseId] = NULL,
                [LeaseExpiresAtUtc] = NULL
            WHERE [Id] = {messageId}
              AND [LeaseId] = {leaseId}
              AND [PublishedAtUtc] IS NULL
              AND [LeaseExpiresAtUtc] > SYSUTCDATETIME();
            """, cancellationToken);

        return changed == 1;
    }

    public async Task<bool> RecordFailureAsync(
        Guid messageId,
        Guid leaseId,
        DateTime nextAttemptAtUtc,
        string error,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(error);
        EnsureSqlServer();
        var changed = await database.Database.ExecuteSqlInterpolatedAsync($"""
            UPDATE [OutboxMessages]
            SET [AttemptCount] = [AttemptCount] + 1,
                [NextAttemptAtUtc] = {nextAttemptAtUtc},
                [LastError] = {error},
                [LeaseId] = NULL,
                [LeaseExpiresAtUtc] = NULL
            WHERE [Id] = {messageId}
              AND [LeaseId] = {leaseId}
              AND [PublishedAtUtc] IS NULL
              AND [LeaseExpiresAtUtc] > SYSUTCDATETIME();
            """, cancellationToken);

        return changed == 1;
    }

    private void EnsureSqlServer()
    {
        if (!database.Database.IsSqlServer())
            throw new NotSupportedException("Outbox leasing requires SQL Server row-lock semantics.");
    }

    private static void ValidateBatchAndDuration(int batchSize, TimeSpan leaseDuration)
    {
        if (batchSize is < 1 or > 500)
            throw new ArgumentOutOfRangeException(nameof(batchSize), "Batch size must be between 1 and 500.");
        ValidateDuration(leaseDuration);
    }

    private static void ValidateDuration(TimeSpan leaseDuration)
    {
        if (leaseDuration <= TimeSpan.Zero || leaseDuration > TimeSpan.FromHours(1))
            throw new ArgumentOutOfRangeException(nameof(leaseDuration), "Lease duration must be greater than zero and at most one hour.");
    }
}
