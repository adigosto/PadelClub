using System;

namespace PadelClub.Model
{
    public class MembershipResponse
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public string MembershipType { get; set; } = string.Empty;
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public decimal Price { get; set; }
        public bool IsActive { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
    }
}
