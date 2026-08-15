namespace PadelClub.Services.Database;

public class NotificationDelivery
{
    public long Id { get; set; }
    public int NotificationId { get; set; }
    public int UserId { get; set; }
    public string Channel { get; set; } = string.Empty;
    public string Status { get; set; } = "Pending";
    public int AttemptCount { get; set; }
    public DateTime NextAttemptAt { get; set; } = DateTime.UtcNow;
    public DateTime? SentAt { get; set; }
    public string? ProviderMessageId { get; set; }
    public string? LastError { get; set; }
    public Notification Notification { get; set; } = null!;
    public User User { get; set; } = null!;
}
