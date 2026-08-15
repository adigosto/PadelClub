using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using PadelClub.Services.Database;

namespace PadelClub.WebAPI.Monitoring;

public sealed class DatabaseHealthCheck(IServiceScopeFactory scopeFactory) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        try
        {
            using var scope = scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
            return await db.Database.CanConnectAsync(cancellationToken) ? HealthCheckResult.Healthy("SQL Server is reachable.") : HealthCheckResult.Unhealthy("SQL Server is unreachable.");
        }
        catch (Exception ex) { return HealthCheckResult.Unhealthy("SQL Server health check failed.", ex); }
    }
}
