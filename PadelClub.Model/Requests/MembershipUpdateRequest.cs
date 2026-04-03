using System;

namespace PadelClub.Model.Requests
{
    public class MembershipUpdateRequest
    {
        public int UserId { get; set; }
        public string MembershipType { get; set; } = string.Empty;
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public decimal Price { get; set; }
        public bool IsActive { get; set; } = true;
    }
}
