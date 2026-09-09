namespace PadelClub.Services.Outbox;

/// <summary>
/// Persists consumer receipt before an externally visible message side effect.
/// Repeated delivery of the same event to the same named consumer is reported
/// as a duplicate rather than processed again.
/// </summary>
public interface IInboxDeduplicationService
{
    Task<InboxReceipt> RecordReceiptAsync(
        string consumer,
        Guid eventId,
        string messageType,
        CancellationToken cancellationToken = default);
}

public sealed record InboxReceipt(bool IsFirstDelivery, DateTime ReceivedAtUtc);
