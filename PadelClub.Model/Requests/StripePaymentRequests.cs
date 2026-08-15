using System.ComponentModel.DataAnnotations;

namespace PadelClub.Model.Requests;

public sealed class CreateStripePaymentRequest
{
    [Required, StringLength(100, MinimumLength = 8)] public string IdempotencyKey { get; set; } = string.Empty;
    public int? ReservationId { get; set; }
    public int? MembershipId { get; set; }
    public int? OrderId { get; set; }
}
public sealed class StripeRefundRequest
{
    public decimal? Amount { get; set; }
    [StringLength(300)] public string Reason { get; set; } = "requested_by_customer";
}
