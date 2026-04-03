using System;

namespace PadelClub.Model.SearchObjects
{
    public class PaymentSearchObject : BaseSearchObject
    {
        public int? UserId { get; set; }
        public string? PaymentType { get; set; }
        public int? ReservationId { get; set; }
        public int? MembershipId { get; set; }
        public int? OrderId { get; set; }
        public string? PaymentMethod { get; set; }
        public string? Status { get; set; }
        public string? TransactionId { get; set; }
        public DateTime? PaymentDateFrom { get; set; }
        public DateTime? PaymentDateTo { get; set; }
    }
}
