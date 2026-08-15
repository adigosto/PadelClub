using System;

namespace PadelClub.Model.Responses
{
    public class AvailabilitySlotResponse
    {
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        public decimal Price { get; set; }
        public bool IsAvailable { get; set; }
    }
}
