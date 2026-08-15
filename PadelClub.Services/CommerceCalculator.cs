using PadelClub.Services.Database;

namespace PadelClub.Services;

public static class CommerceCalculator
{
    public static decimal CouponDiscount(Coupon coupon, decimal subtotal)
    {
        if (subtotal < coupon.MinimumOrderAmount) return 0;
        var discount = coupon.DiscountType == "Percentage" ? subtotal * coupon.Value / 100m : coupon.Value;
        if (coupon.MaximumDiscount.HasValue) discount = Math.Min(discount, coupon.MaximumDiscount.Value);
        return decimal.Round(Math.Clamp(discount, 0, subtotal), 2, MidpointRounding.AwayFromZero);
    }
}
