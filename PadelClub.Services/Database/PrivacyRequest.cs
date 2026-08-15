namespace PadelClub.Services.Database;

public class PrivacyRequest
{
    public long Id { get; set; }
    public int UserId { get; set; }
    public string RequestType { get; set; } = "Deletion";
    public string Status { get; set; } = "Scheduled";
    public DateTime RequestedAt { get; set; } = DateTime.UtcNow;
    public DateTime ScheduledFor { get; set; }
    public DateTime? CompletedAt { get; set; }
    public DateTime? CancelledAt { get; set; }
    public User User { get; set; } = null!;
}
