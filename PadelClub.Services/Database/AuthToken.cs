namespace PadelClub.Services.Database;

public class AuthToken
{
    public long Id { get; set; }
    public int UserId { get; set; }
    public string TokenHash { get; set; } = string.Empty;
    public string Purpose { get; set; } = string.Empty;
    public DateTime ExpiresAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? ConsumedAt { get; set; }
    public DateTime? RevokedAt { get; set; }
    public long? ReplacedByTokenId { get; set; }
    public string? FamilyId { get; set; }
    public virtual User User { get; set; } = null!;
}
