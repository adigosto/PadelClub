using System.ComponentModel.DataAnnotations;
using System.Collections.Generic;
using System;

namespace PadelClub.Model.Requests
{
    public class CheckoutRequest
    {
        [Required, StringLength(100, MinimumLength = 8, ErrorMessage = "Idempotency key must contain 8–100 characters.")]
        public string IdempotencyKey { get; set; } = string.Empty;

        [Required(ErrorMessage = "Enter the recipient name.")]
        [StringLength(150, MinimumLength = 2, ErrorMessage = "Recipient name must contain 2–150 characters.")]
        public string RecipientName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Enter a phone number.")]
        [StringLength(30, MinimumLength = 6, ErrorMessage = "Phone number must contain 6–30 characters.")]
        public string PhoneNumber { get; set; } = string.Empty;

        [Required(ErrorMessage = "Enter the street address.")]
        [StringLength(500, MinimumLength = 5, ErrorMessage = "Street address must contain 5–500 characters.")]
        public string ShippingAddress { get; set; } = string.Empty;

        [Required(ErrorMessage = "Enter the city.")]
        [StringLength(100, MinimumLength = 2, ErrorMessage = "City must contain 2–100 characters.")]
        public string City { get; set; } = string.Empty;

        [Required(ErrorMessage = "Enter the postal code.")]
        [StringLength(20, MinimumLength = 3, ErrorMessage = "Postal code must contain 3–20 characters.")]
        public string PostalCode { get; set; } = string.Empty;

        [MaxLength(1000, ErrorMessage = "Delivery notes must contain no more than 1000 characters.")]
        public string? Notes { get; set; }

        [MaxLength(40, ErrorMessage = "Coupon code must contain no more than 40 characters.")]
        public string? CouponCode { get; set; }

        [Required(ErrorMessage = "Add an item to your cart.")]
        [MinLength(1, ErrorMessage = "Add an item to your cart.")]
        public List<CheckoutLineRequest> Items { get; set; } = new();
    }

    public class CheckoutLineRequest
    {
        public int ProductId { get; set; }

        [Range(1, 100, ErrorMessage = "Choose a quantity from 1 to 100.")]
        public int Quantity { get; set; }

        /// <summary>
        /// Optional server-issued recommendation exposure for this exact
        /// product. The server validates ownership, click state, product, and
        /// a short attribution window before recording it.
        /// </summary>
        public Guid? RecommendationExposureId { get; set; }
    }
}
