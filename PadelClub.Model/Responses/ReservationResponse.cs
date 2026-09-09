using System;
using System.Text.Json.Serialization;
using PadelClub.Model.Serialization;

namespace PadelClub.Model
{
    public class ReservationResponse
    {
        public int Id { get; set; }
        public int CourtId { get; set; }
        public string CourtName { get; set; } = string.Empty;
        public string UserName { get; set; } = string.Empty;
        public int UserId { get; set; }
        [JsonConverter(typeof(UtcDateTimeJsonConverter))]
        public DateTime StartTime { get; set; }
        [JsonConverter(typeof(UtcDateTimeJsonConverter))]
        public DateTime EndTime { get; set; }
        public decimal TotalPrice { get; set; }
        public string Status { get; set; } = string.Empty;
        public string? Notes { get; set; }
        [JsonConverter(typeof(UtcDateTimeJsonConverter))]
        public DateTime CreatedAt { get; set; }
        [JsonConverter(typeof(UtcDateTimeJsonConverter))]
        public DateTime? UpdatedAt { get; set; }
        public Guid? SeriesId { get; set; }
        [JsonConverter(typeof(UtcDateTimeJsonConverter))]
        public DateTime? CancelledAt { get; set; }
        public string? CancellationReason { get; set; }
        public bool IsNoShow { get; set; }
    }
}

