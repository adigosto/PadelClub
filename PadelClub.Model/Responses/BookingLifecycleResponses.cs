using System;

namespace PadelClub.Model.Responses;

public sealed class WaitlistEntryResponse
{
    public int Id { get; set; }
    public int CourtId { get; set; }
    public DateTime StartTimeUtc { get; set; }
    public DateTime EndTimeUtc { get; set; }
    public string Status { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}
public sealed class AccountCreditResponse
{
    public int Id { get; set; }
    public int? ReservationId { get; set; }
    public decimal Amount { get; set; }
    public string Reason { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime? UsedAt { get; set; }
}
