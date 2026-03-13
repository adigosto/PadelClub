using System;

namespace PadelClub.Services.Database
{
    public class Payment
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public string PaymentType { get; set; } = string.Empty; // Reservation, Membership, Product
        public int? ReservationId { get; set; }
        public int? MembershipId { get; set; }
        public int? OrderId { get; set; }
        public decimal Amount { get; set; }
        public string PaymentMethod { get; set; } = string.Empty; // CreditCard, Cash, BankTransfer
        public string Status { get; set; } = "Pending"; // Pending, Completed, Failed, Refunded
        public string? TransactionId { get; set; }
        public DateTime PaymentDate { get; set; } = DateTime.UtcNow;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Navigation properties
        public virtual User User { get; set; } = null!;
        public virtual Reservation? Reservation { get; set; }
        public virtual Membership? Membership { get; set; }
        public virtual Order? Order { get; set; }
    }
}

