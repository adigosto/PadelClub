using System.ComponentModel.DataAnnotations;
using System;

namespace PadelClub.Model.Requests;

public sealed class RecurringReservationRequest
{
    public int CourtId { get; set; }
    public DateTime StartTime { get; set; }
    public DateTime EndTime { get; set; }
    [Range(1, 52)] public int Weeks { get; set; } = 1;
    [StringLength(1000)] public string? Notes { get; set; }
}
public sealed class WaitlistRequest
{
    public int CourtId { get; set; }
    public DateTime StartTime { get; set; }
    public DateTime EndTime { get; set; }
}
public sealed class MaintenanceBlockRequest
{
    public int? CourtId { get; set; }
    public DateTime StartTimeUtc { get; set; }
    public DateTime EndTimeUtc { get; set; }
    [Required, StringLength(500)] public string Reason { get; set; } = string.Empty;
}
