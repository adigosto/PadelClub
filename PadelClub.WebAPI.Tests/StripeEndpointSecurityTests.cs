using Microsoft.AspNetCore.Authorization;
using PadelClub.WebAPI.Controllers;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public class StripeEndpointSecurityTests
{
    [Fact]
    public void Only_webhook_is_anonymous()
    {
        var methods = typeof(StripePaymentsController).GetMethods().Where(x => x.DeclaringType == typeof(StripePaymentsController)).ToList();
        Assert.NotNull(methods.Single(x => x.Name == "Webhook").GetCustomAttributes(typeof(AllowAnonymousAttribute), true).SingleOrDefault());
        Assert.Empty(methods.Single(x => x.Name == "CreateIntent").GetCustomAttributes(typeof(AllowAnonymousAttribute), true));
    }

    [Fact]
    public void Refund_requires_admin_policy()
    {
        var refund = typeof(StripePaymentsController).GetMethod("Refund")!;
        Assert.Contains(refund.GetCustomAttributes(typeof(AuthorizeAttribute), true).Cast<AuthorizeAttribute>(), x => x.Policy == "AdminOnly");
    }
}
