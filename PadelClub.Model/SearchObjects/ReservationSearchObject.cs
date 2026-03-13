using System;
using System.Collections.Generic;
using System.Text;

namespace PadelClub.Model.SearchObjects
{
    public class ReservationSearchObject : BaseSearchObject
    {
        public int? CourtId { get; set; }
        public int? UserId { get; set; }
        public string? Status { get; set; }
        public DateTime? StartTimeFrom { get; set; }
        public DateTime? StartTimeTo { get; set; }
        public DateTime? EndTimeFrom { get; set; }
        public DateTime? EndTimeTo { get; set; }
    }
}

