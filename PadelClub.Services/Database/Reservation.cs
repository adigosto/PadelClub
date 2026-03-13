using System;

namespace PadelClub.Services.Database
{
    public class Reservation
    {
        public int Id { get; set; }
        public int CourtId { get; set; }
        public int UserId { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        public decimal TotalPrice { get; set; }
        public string Status { get; set; } = "Pending"; // Pending, Confirmed, Cancelled, Completed
        public string? Notes { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? UpdatedAt { get; set; }

        // Navigation properties
        public virtual Court Court { get; set; } = null!;
        public virtual User User { get; set; } = null!;
        public virtual Payment? Payment { get; set; }
    }
}

