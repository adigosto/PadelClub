namespace PadelClub.Services.Database;

public class PartnerInvitation
{
    public int Id { get; set; }
    public int SenderUserId { get; set; }
    public int RecipientUserId { get; set; }
    public string Message { get; set; } = string.Empty;
    public string Status { get; set; } = "Pending";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? RespondedAt { get; set; }
    public User Sender { get; set; } = null!;
    public User Recipient { get; set; } = null!;
}
