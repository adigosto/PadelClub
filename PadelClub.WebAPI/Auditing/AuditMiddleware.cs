using System.Diagnostics;
using System.Security.Claims;
using PadelClub.Services.Database;

namespace PadelClub.WebAPI.Auditing;

public sealed class AuditMiddleware(RequestDelegate next, IServiceScopeFactory scopeFactory, ILogger<AuditMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        if (HttpMethods.IsGet(context.Request.Method) || HttpMethods.IsHead(context.Request.Method) || HttpMethods.IsOptions(context.Request.Method))
        {
            await next(context); return;
        }
        var timer = Stopwatch.StartNew();
        try { await next(context); }
        finally
        {
            timer.Stop();
            try
            {
                int? userId = int.TryParse(context.User.FindFirstValue(ClaimTypes.NameIdentifier), out var parsed) ? parsed : null;
                using var scope = scopeFactory.CreateScope();
                var auditDb = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
                auditDb.AuditLogs.Add(new AuditLog { UserId = userId, Method = context.Request.Method, Path = context.Request.Path.Value ?? "/", StatusCode = context.Response.StatusCode,
                    IpAddress = context.Connection.RemoteIpAddress?.ToString() ?? "unknown", CorrelationId = context.TraceIdentifier, DurationMs = timer.ElapsedMilliseconds });
                await auditDb.SaveChangesAsync(context.RequestAborted);
            }
            catch (Exception ex) { logger.LogError(ex, "Failed to persist request audit record {CorrelationId}.", context.TraceIdentifier); }
        }
    }
}
