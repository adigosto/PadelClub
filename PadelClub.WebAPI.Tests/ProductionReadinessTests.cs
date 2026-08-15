using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using PadelClub.Services.Database;
using PadelClub.WebAPI.Controllers;
using PadelClub.WebAPI.Monitoring;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public class ProductionReadinessTests
{
    [Fact]
    public void Privacy_endpoints_require_authentication() =>
        Assert.NotEmpty(typeof(PrivacyController).GetCustomAttributes(typeof(AuthorizeAttribute), true));

    [Fact]
    public void Deletion_requests_default_to_scheduled()
    {
        var requested = DateTime.UtcNow;
        var item = new PrivacyRequest { RequestedAt = requested, ScheduledFor = requested.AddDays(30) };
        Assert.Equal("Scheduled", item.Status);
        Assert.Equal(TimeSpan.FromDays(30), item.ScheduledFor - item.RequestedAt);
    }

    [Fact]
    public void Database_check_uses_standard_health_contract() =>
        Assert.True(typeof(IHealthCheck).IsAssignableFrom(typeof(DatabaseHealthCheck)));
}
