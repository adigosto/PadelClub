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
        public string ResultStatus { get; set; } = "None";
        public int? ReportedByUserId { get; set; }
        public int? ProposedWinnerTeamId { get; set; }
        public string? ProposedScore { get; set; }
        public DateTime? ResultReportedAt { get; set; }
        public DateTime? ResultConfirmedAt { get; set; }
        public int? TeamOneRatingChange { get; set; }
        public int? TeamTwoRatingChange { get; set; }
        public int? BracketRound { get; set; }
        public int? BracketPosition { get; set; }
        public int? NextMatchId { get; set; }
        public int? NextMatchTeamNumber { get; set; }
        public bool IsBye { get; set; }
        public Match? NextMatch { get; set; }
        public ICollection<Match> PreviousMatches { get; set; } = new List<Match>();

        // Navigation properties
        public virtual Tournament Tournament { get; set; } = null!;
        public virtual Court Court { get; set; } = null!;
        public virtual ICollection<MatchParticipant> Participants { get; set; } = new List<MatchParticipant>();
    }
}

