namespace PadelClub.Model.SearchObjects
{
    public class MatchParticipantSearchObject : BaseSearchObject
    {
        public int? MatchId { get; set; }
        public int? UserId { get; set; }
        public int? TeamNumber { get; set; }
        public string? Role { get; set; }
    }
}
