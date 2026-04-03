using System;

namespace PadelClub.Model.Requests
{
    public class TournamentParticipantInsertRequest
    {
        public int TournamentId { get; set; }
        public int UserId { get; set; }
        public string Status { get; set; } = "Registered";
        public DateTime? ConfirmedAt { get; set; }
    }
}
