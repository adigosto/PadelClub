using System;

namespace PadelClub.Model
{
    public class TournamentResponse
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public DateTime RegistrationDeadline { get; set; }
        public int MaxParticipants { get; set; }
        public decimal EntryFee { get; set; }
        public string Status { get; set; } = "Upcoming"; // Upcoming, Ongoing, Completed, Cancelled
        public string? PrizeInfo { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? UpdatedAt { get; set; }
    }
}

