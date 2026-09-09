namespace PadelClub.Services.Database;

/// <summary>
/// Durable record of a message accepted by a named consumer. The unique
/// consumer/event pair makes at-least-once broker delivery safe for consumers
/// whose side effect is committed only after this record is written.
/// </summary>
public sealed class InboxMessage
{
    public long Id { get; set; }

    public string Consumer { get; set; } = string.Empty;

    public Guid EventId { get; set; }

    public string MessageType { get; set; } = string.Empty;

    public DateTime ReceivedAtUtc { get; set; } = DateTime.UtcNow;
}
