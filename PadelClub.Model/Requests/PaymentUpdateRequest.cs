using System;

namespace PadelClub.Model.Requests
{
    public class PaymentUpdateRequest
    {
        public int UserId { get; set; }
        public string PaymentType { get; set; } = string.Empty;
        public int? ReservationId { get; set; }
        public int? MembershipId { get; set; }
        public int? OrderId { get; set; }
        public decimal Amount { get; set; }
        public string PaymentMethod { get; set; } = string.Empty;
        public string Status { get; set; } = "Pending";
        public string? TransactionId { get; set; }
        public DateTime PaymentDate { get; set; } = DateTime.UtcNow;
    }
}
