using System;
using System.Collections.Generic;

namespace PadelClub.Model.Responses
{
    public class MatchSummaryResponse
    {
        public int Id { get; set; }
        public string TournamentName { get; set; } = string.Empty;
        public string CourtName { get; set; } = string.Empty;
        public DateTime ScheduledTime { get; set; }
        public string Status { get; set; } = string.Empty;
        public string? Score { get; set; }
        public List<string> TeamOne { get; set; } = new();
        public List<string> TeamTwo { get; set; } = new();
    }

    public class PlayerRankingResponse
    {
        public int UserId { get; set; }
        public string PlayerName { get; set; } = string.Empty;
        public int MatchesPlayed { get; set; }
        public int Wins { get; set; }
        public int Rating { get; set; }
        public double WinRate { get; set; }
    }
}
