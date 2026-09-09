using System;
using System.Text.Json.Serialization;
using PadelClub.Model.Serialization;

namespace PadelClub.Model.Responses;

public sealed class WaitlistEntryResponse
{
    public int Id { get; set; }
    public int CourtId { get; set; }
    public string CourtName { get; set; } = string.Empty;
    [JsonConverter(typeof(UtcDateTimeJsonConverter))]
    public DateTime StartTimeUtc { get; set; }
    [JsonConverter(typeof(UtcDateTimeJsonConverter))]
    public DateTime EndTimeUtc { get; set; }
    public string Status { get; set; } = string.Empty;
    [JsonConverter(typeof(UtcDateTimeJsonConverter))]
    public DateTime CreatedAt { get; set; }
}
public sealed class AccountCreditResponse
{
    public int Id { get; set; }
    public int? ReservationId { get; set; }
    public decimal Amount { get; set; }
    public string Reason { get; set; } = string.Empty;
    [JsonConverter(typeof(UtcDateTimeJsonConverter))]
    public DateTime CreatedAt { get; set; }
    [JsonConverter(typeof(UtcDateTimeJsonConverter))]
    public DateTime? UsedAt { get; set; }
}
