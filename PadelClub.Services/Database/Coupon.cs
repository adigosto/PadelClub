namespace PadelClub.Services.Database;

public class Coupon
{
    public int Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string DiscountType { get; set; } = "Percentage";
    public decimal Value { get; set; }
    public decimal MinimumOrderAmount { get; set; }
    public decimal? MaximumDiscount { get; set; }
    public DateTime ValidFrom { get; set; }
    public DateTime ValidUntil { get; set; }
    public int? UsageLimit { get; set; }
    public int UsageCount { get; set; }
    public int PerUserLimit { get; set; } = 1;
    public bool IsActive { get; set; } = true;
    public ICollection<CouponRedemption> Redemptions { get; set; } = new List<CouponRedemption>();
}

public class CouponRedemption
{
    public long Id { get; set; }
    public int CouponId { get; set; }
    public int UserId { get; set; }
    public int OrderId { get; set; }
    public decimal DiscountAmount { get; set; }
    public DateTime RedeemedAt { get; set; } = DateTime.UtcNow;
    public Coupon Coupon { get; set; } = null!;
}
