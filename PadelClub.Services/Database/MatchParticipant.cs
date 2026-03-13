using System;

namespace PadelClub.Services.Database
{
    public class MatchParticipant
    {
        public int Id { get; set; }
        public int MatchId { get; set; }
        public int UserId { get; set; }
        public int TeamNumber { get; set; } // 1 or 2
        public string Role { get; set; } = "Player"; // Player, Captain
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Navigation properties
        public virtual Match Match { get; set; } = null!;
        public virtual User User { get; set; } = null!;
    }
}

