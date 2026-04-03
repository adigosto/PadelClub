using System;

namespace PadelClub.Model
{
    public class MatchParticipantResponse
    {
        public int Id { get; set; }
        public int MatchId { get; set; }
        public int UserId { get; set; }
        public int TeamNumber { get; set; }
        public string Role { get; set; } = "Player";
        public DateTime CreatedAt { get; set; }
    }
}
