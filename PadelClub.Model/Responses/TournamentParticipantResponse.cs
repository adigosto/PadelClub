using System;

namespace PadelClub.Model
{
    public class TournamentParticipantResponse
    {
        public int Id { get; set; }
        public int TournamentId { get; set; }
        public int UserId { get; set; }
        public string Status { get; set; } = "Registered";
        public DateTime RegisteredAt { get; set; }
        public DateTime? ConfirmedAt { get; set; }
    }
}
