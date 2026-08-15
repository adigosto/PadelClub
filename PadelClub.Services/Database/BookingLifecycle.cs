namespace PadelClub.Services.Database;

public class MaintenanceBlock
{
    public int Id { get; set; }
    public int? CourtId { get; set; }
    public DateTime StartTimeUtc { get; set; }
    public DateTime EndTimeUtc { get; set; }
    public string Reason { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public Court? Court { get; set; }
}

public class WaitlistEntry
{
    public int Id { get; set; }
    public int CourtId { get; set; }
    public int UserId { get; set; }
    public DateTime StartTimeUtc { get; set; }
    public DateTime EndTimeUtc { get; set; }
    public string Status { get; set; } = "Waiting";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? PromotedAt { get; set; }
    public Court Court { get; set; } = null!;
    public User User { get; set; } = null!;
}

public class AccountCredit
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public int? ReservationId { get; set; }
    public decimal Amount { get; set; }
    public string Reason { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UsedAt { get; set; }
    public User User { get; set; } = null!;
    public Reservation? Reservation { get; set; }
}
