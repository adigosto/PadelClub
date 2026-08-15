namespace PadelClub.Services.Database;

public class StripeWebhookEvent
{
    public long Id { get; set; }
    public string StripeEventId { get; set; } = string.Empty;
    public string EventType { get; set; } = string.Empty;
    public DateTime ReceivedAt { get; set; } = DateTime.UtcNow;
    public DateTime? ProcessedAt { get; set; }
    public string? ProcessingError { get; set; }
}
