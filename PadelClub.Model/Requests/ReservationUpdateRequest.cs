using System;

namespace PadelClub.Model.Requests
{
    public class ReservationUpdateRequest
    {
        public int CourtId { get; set; }
        public int UserId { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        public decimal TotalPrice { get; set; }
        public string Status { get; set; } = "Pending";
        public string? Notes { get; set; }
    }
}
