namespace PadelClub.Services.Database;

public class NotificationPreference
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public bool InAppEnabled { get; set; } = true;
    public bool EmailEnabled { get; set; } = true;
    public bool PushEnabled { get; set; } = true;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public User User { get; set; } = null!;
}
