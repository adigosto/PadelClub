using System.Collections.Generic;

namespace PadelClub.Model.Responses
{
    public class CourtAvailabilityResponse
    {
        public int CourtId { get; set; }
        public string CourtName { get; set; } = string.Empty;
        public bool IsIndoor { get; set; }
        public int MaxPlayers { get; set; }
        public decimal HourlyRate { get; set; }
        public List<AvailabilitySlotResponse> Slots { get; set; } = new();
    }
}
