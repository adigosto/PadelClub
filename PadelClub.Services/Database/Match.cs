using System;

namespace PadelClub.Services.Database
{
    public class Match
    {
        public int Id { get; set; }
        public int TournamentId { get; set; }
        public int CourtId { get; set; }
        public DateTime ScheduledTime { get; set; }
        public DateTime? ActualStartTime { get; set; }
        public DateTime? ActualEndTime { get; set; }
        public string Status { get; set; } = "Scheduled"; // Scheduled, InProgress, Completed, Cancelled
        public int? WinnerTeamId { get; set; }
        public string? Score { get; set; }
        public string? Notes { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? UpdatedAt { get; set; }

        // Navigation properties
        public virtual Tournament Tournament { get; set; } = null!;
        public virtual Court Court { get; set; } = null!;
        public virtual ICollection<MatchParticipant> Participants { get; set; } = new List<MatchParticipant>();
    }
}

