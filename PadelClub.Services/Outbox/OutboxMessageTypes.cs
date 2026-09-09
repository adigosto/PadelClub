namespace PadelClub.Services.Outbox;

/// <summary>
/// Stable routing names for durable integration events. Keep these independent
/// of CLR type names so a refactor does not strand previously committed rows.
/// </summary>
public static class OutboxMessageTypes
{
    public const string ProductUpdated = "product.updated.v1";
}
