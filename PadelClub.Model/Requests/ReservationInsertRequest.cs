using System;
using System.Text.Json.Serialization;

namespace PadelClub.Model.Requests
{
    public class ReservationInsertRequest
    {
        public int CourtId { get; set; }
        [JsonIgnore]
        public int UserId { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        [JsonIgnore]
        public decimal TotalPrice { get; set; }
        [JsonIgnore]
        public string Status { get; set; } = "Pending";
        public string? Notes { get; set; }
    }
}
