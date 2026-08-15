namespace PadelClub.Services.Database;

public class PushDevice
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public string InstallationId { get; set; } = string.Empty;
    public string Platform { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime LastSeenAt { get; set; } = DateTime.UtcNow;
    public User User { get; set; } = null!;
}
