using System;
using System.Text.Json.Serialization;
using PadelClub.Model.Serialization;

namespace PadelClub.Model.Responses
{
    public class AvailabilitySlotResponse
    {
        [JsonConverter(typeof(UtcDateTimeJsonConverter))]
        public DateTime StartTime { get; set; }
        [JsonConverter(typeof(UtcDateTimeJsonConverter))]
        public DateTime EndTime { get; set; }
        public decimal Price { get; set; }
        public bool IsAvailable { get; set; }
        /// <summary>
        /// True only when an upcoming slot is occupied by an existing reservation
        /// and can therefore be joined through the reservation waitlist.
        /// </summary>
        public bool IsWaitlistEligible { get; set; }
    }
}
