using System;

namespace PadelClub.Services.Database
{
    public class Order
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public string OrderNumber { get; set; } = string.Empty;
        public decimal TotalAmount { get; set; }
        public string Status { get; set; } = "Pending"; // Pending, Processing, Shipped, Delivered, Cancelled
        public string RecipientName { get; set; } = string.Empty;
        public string PhoneNumber { get; set; } = string.Empty;
        public string ShippingAddress { get; set; } = string.Empty;
        public string City { get; set; } = string.Empty;
        public string PostalCode { get; set; } = string.Empty;
        public string? Notes { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? UpdatedAt { get; set; }

        // Navigation properties
        public string? IdempotencyKey { get; set; }
        public virtual User User { get; set; } = null!;
        public virtual ICollection<OrderItem> OrderItems { get; set; } = new List<OrderItem>();
        public virtual Payment? Payment { get; set; }
        public decimal SubtotalAmount { get; set; }
        public decimal DiscountAmount { get; set; }
        public int? CouponId { get; set; }
        public string? CouponCode { get; set; }
        public DateTime? DeliveredAt { get; set; }
        /// <summary>
        /// Marks development seed data. These records remain available to the
        /// player-facing demo recommender but are never valid offline-quality
        /// evaluation evidence.
        /// </summary>
        public bool IsSeededForDemo { get; set; }
        /// <summary>
        /// Explicit provenance used by the operational recommendation evidence
        /// path. Only <see cref="OrderOrigin.CustomerCheckout"/> and
        /// <see cref="OrderOrigin.VerifiedImport"/> may contribute to a
        /// qualified cohort.
        /// </summary>
        public OrderOrigin Origin { get; set; } = OrderOrigin.UnverifiedLegacy;
        public virtual ICollection<ReturnRequest> ReturnRequests { get; set; } = new List<ReturnRequest>();
    }
}

