namespace PadelClub.Model.Requests
{
    public class MatchParticipantInsertRequest
    {
        public int MatchId { get; set; }
        public int UserId { get; set; }
        public int TeamNumber { get; set; }
        public string Role { get; set; } = "Player";
    }
}
