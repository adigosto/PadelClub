using System;

namespace PadelClub.Services.Database
{
    public class Membership
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public string MembershipType { get; set; } = string.Empty; // Basic, Premium, VIP
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public decimal Price { get; set; }
        public bool IsActive { get; set; } = true;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? UpdatedAt { get; set; }

        // Navigation properties
        public virtual User User { get; set; } = null!;
        public virtual Payment? Payment { get; set; }
    }
}

