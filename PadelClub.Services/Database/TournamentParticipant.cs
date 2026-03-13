using System;

namespace PadelClub.Services.Database
{
    public class TournamentParticipant
    {
        public int Id { get; set; }
        public int TournamentId { get; set; }
        public int UserId { get; set; }
        public string Status { get; set; } = "Registered"; // Registered, Confirmed, Withdrawn
        public DateTime RegisteredAt { get; set; } = DateTime.UtcNow;
        public DateTime? ConfirmedAt { get; set; }

        // Navigation properties
        public virtual Tournament Tournament { get; set; } = null!;
        public virtual User User { get; set; } = null!;
    }
}

