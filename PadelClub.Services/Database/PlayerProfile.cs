namespace PadelClub.Services.Database;

public class PlayerProfile
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public string SkillLevel { get; set; } = "Beginner";
    public string PreferredSide { get; set; } = "Either";
    public string City { get; set; } = string.Empty;
    public string Bio { get; set; } = string.Empty;
    public string Availability { get; set; } = string.Empty;
    public bool IsDiscoverable { get; set; } = true;
    public int Rating { get; set; } = 1000;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public User User { get; set; } = null!;
}
