using System;

namespace PadelClub.Model.Requests
{
    public class TournamentUpdateRequest
    {
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public DateTime RegistrationDeadline { get; set; }
        public int MaxParticipants { get; set; }
        public decimal EntryFee { get; set; }
        public string? PrizeInfo { get; set; }
    }
}

