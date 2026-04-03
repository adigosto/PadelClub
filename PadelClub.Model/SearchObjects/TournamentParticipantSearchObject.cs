namespace PadelClub.Model.SearchObjects
{
    public class TournamentParticipantSearchObject : BaseSearchObject
    {
        public int? TournamentId { get; set; }
        public int? UserId { get; set; }
        public string? Status { get; set; }
    }
}
