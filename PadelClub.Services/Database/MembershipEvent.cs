namespace PadelClub.Services.Database;

public class MembershipEvent
{
    public long Id { get; set; }
    public int MembershipId { get; set; }
    public string EventType { get; set; } = string.Empty;
    public string Notes { get; set; } = string.Empty;
    public int? ActorUserId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public Membership Membership { get; set; } = null!;
}
