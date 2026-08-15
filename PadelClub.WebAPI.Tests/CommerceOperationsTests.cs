using Microsoft.AspNetCore.Authorization;
using PadelClub.Services;
using PadelClub.Services.Database;
using PadelClub.WebAPI.Controllers;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public class CommerceOperationsTests
{
    [Fact]
    public void Percentage_coupon_honors_maximum_discount()
    {
        var coupon = new Coupon { DiscountType = "Percentage", Value = 25, MaximumDiscount = 20, MinimumOrderAmount = 50 };
        Assert.Equal(20m, CommerceCalculator.CouponDiscount(coupon, 100m));
    }

    [Fact]
    public void Fixed_coupon_never_makes_total_negative()
    {
        var coupon = new Coupon { DiscountType = "Fixed", Value = 500 };
        Assert.Equal(40m, CommerceCalculator.CouponDiscount(coupon, 40m));
    }

    [Fact]
    public void Operations_endpoints_are_admin_only() =>
        Assert.Contains(typeof(OperationsController).GetCustomAttributes(typeof(AuthorizeAttribute), true).Cast<AuthorizeAttribute>(), x => x.Policy == "AdminOnly");
}
