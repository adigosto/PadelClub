using Microsoft.AspNetCore.Authorization;
using PadelClub.Services.Database;
using PadelClub.WebAPI.Controllers;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public class TournamentMembershipLifecycleTests
{
    [Fact]
    public void Bracket_generation_is_admin_only()
    {
        var method = typeof(TournamentLifecycleController).GetMethod(nameof(TournamentLifecycleController.Generate));
        var authorization = Assert.Single(method!.GetCustomAttributes(typeof(AuthorizeAttribute), true).Cast<AuthorizeAttribute>());
        Assert.Equal("AdminOnly", authorization.Policy);
    }

    [Fact]
    public void New_membership_has_explicit_active_state()
    {
        var membership = new Membership();
        Assert.True(membership.IsActive);
        Assert.Equal("Active", membership.Status);
        Assert.False(membership.AutoRenew);
        Assert.False(membership.CancelAtPeriodEnd);
    }
}
