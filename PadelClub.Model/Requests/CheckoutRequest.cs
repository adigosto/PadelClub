using System.ComponentModel.DataAnnotations;
using System.Collections.Generic;

namespace PadelClub.Model.Requests
{
    public class CheckoutRequest
    {
        [Required]
        [MaxLength(150)]
        public string RecipientName { get; set; } = string.Empty;

        [Required]
        [MaxLength(30)]
        public string PhoneNumber { get; set; } = string.Empty;

        [Required]
        [MaxLength(500)]
        public string ShippingAddress { get; set; } = string.Empty;

        [Required]
        [MaxLength(100)]
        public string City { get; set; } = string.Empty;

        [Required]
        [MaxLength(20)]
        public string PostalCode { get; set; } = string.Empty;

        [MaxLength(1000)]
        public string? Notes { get; set; }

        [MaxLength(40)]
        public string? CouponCode { get; set; }

        [Required]
        [MinLength(1)]
        public List<CheckoutLineRequest> Items { get; set; } = new();
    }

    public class CheckoutLineRequest
    {
        public int ProductId { get; set; }

        [Range(1, 100)]
        public int Quantity { get; set; }
    }
}
