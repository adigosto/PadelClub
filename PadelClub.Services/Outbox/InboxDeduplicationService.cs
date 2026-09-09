using Microsoft.EntityFrameworkCore;
using PadelClub.Services.Database;

namespace PadelClub.Services.Outbox;

/// <summary>
/// Uses a serializable key-range check followed by an insert as the concurrency
/// boundary for consumer idempotency. It is safe when multiple replicas receive
/// the same broker event concurrently without turning expected duplicates into
/// noisy database exceptions.
/// </summary>
public sealed class InboxDeduplicationService(PadelClubContext database) : IInboxDeduplicationService
{
    public async Task<InboxReceipt> RecordReceiptAsync(
        string consumer,
        Guid eventId,
        string messageType,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(consumer);
        ArgumentException.ThrowIfNullOrWhiteSpace(messageType);
        if (eventId == Guid.Empty)
            throw new ArgumentException("Event ID must be non-empty.", nameof(eventId));

        if (!database.Database.IsSqlServer())
            throw new NotSupportedException("Durable inbox deduplication requires SQL Server key-range locks.");

        var receivedAtUtc = DateTime.UtcNow;
        var inserted = await database.Database.ExecuteSqlInterpolatedAsync($"""
            INSERT INTO [InboxMessages] ([Consumer], [EventId], [MessageType], [ReceivedAtUtc])
            SELECT {consumer}, {eventId}, {messageType}, SYSUTCDATETIME()
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM [InboxMessages] WITH (UPDLOCK, HOLDLOCK)
                WHERE [Consumer] = {consumer} AND [EventId] = {eventId}
            );
            """, cancellationToken);

        return new InboxReceipt(inserted == 1, receivedAtUtc);
    }
}
