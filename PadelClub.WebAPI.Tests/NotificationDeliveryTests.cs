using Microsoft.AspNetCore.Authorization;
using PadelClub.WebAPI.Controllers;
using PadelClub.WebAPI.Notifications;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public class NotificationDeliveryTests
{
    [Fact]
    public void Delivery_retry_defaults_are_bounded()
    {
        var options = new NotificationDeliveryOptions();
        Assert.InRange(options.PollSeconds, 2, 60);
        Assert.InRange(options.MaxAttempts, 1, 20);
    }

    [Fact]
    public void Delivery_diagnostics_require_admin_policy()
    {
        var method = typeof(NotificationSettingsController).GetMethod(nameof(NotificationSettingsController.Deliveries));
        var policy = Assert.Single(method!.GetCustomAttributes(typeof(AuthorizeAttribute), true).Cast<AuthorizeAttribute>());
        Assert.Equal("AdminOnly", policy.Policy);
    }
}
