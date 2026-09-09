using Microsoft.AspNetCore.Authorization;
using PadelClub.WebAPI.Controllers;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public class StripeEndpointSecurityTests
{
    [Fact]
    public void Only_webhook_is_anonymous()
    {
        var webhook = typeof(StripeWebhookController).GetMethod("Webhook")!;
        Assert.Empty(webhook.GetCustomAttributes(typeof(AllowAnonymousAttribute), true));
        Assert.Empty(typeof(StripePaymentsController).GetMethods().Where(x => x.DeclaringType == typeof(StripePaymentsController)).SelectMany(x => x.GetCustomAttributes(typeof(AllowAnonymousAttribute), true)));
    }

    [Fact]
    public void Refund_requires_admin_policy()
    {
        var refund = typeof(StripePaymentsController).GetMethod("Refund")!;
        Assert.Contains(refund.GetCustomAttributes(typeof(AuthorizeAttribute), true).Cast<AuthorizeAttribute>(), x => x.Policy == "AdminOnly");
    }
}
