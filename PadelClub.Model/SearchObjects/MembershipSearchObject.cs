using System;

namespace PadelClub.Model.SearchObjects
{
    public class MembershipSearchObject : BaseSearchObject
    {
        public int? UserId { get; set; }
        public string? MembershipType { get; set; }
        public bool? IsActive { get; set; }
        public DateTime? StartDateFrom { get; set; }
        public DateTime? StartDateTo { get; set; }
        public DateTime? EndDateFrom { get; set; }
        public DateTime? EndDateTo { get; set; }
    }
}
