using Microsoft.EntityFrameworkCore;
using PadelClub.Services.Database;
using PadelClub.Services;
using PadelClub.Model.Requests;

namespace PadelClub.WebAPI.Memberships;

public sealed class MembershipLifecycleWorker(IServiceScopeFactory scopeFactory, ILogger<MembershipLifecycleWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
                var expired = await db.Memberships.Where(x => x.Status == "Active" && x.EndDate <= DateTime.UtcNow).ToListAsync(stoppingToken);
                foreach (var membership in expired)
                {
                    membership.Status = membership.CancelAtPeriodEnd ? "Cancelled" : membership.AutoRenew ? "RenewalDue" : "Expired";
                    membership.IsActive = false; membership.UpdatedAt = DateTime.UtcNow;
                    if (membership.Status == "Cancelled") membership.CancelledAt = DateTime.UtcNow;
                    membership.Events.Add(new MembershipEvent { EventType = membership.Status, Notes = membership.AutoRenew ? "Automatic renewal requires payment." : "Membership period ended." });
                }
                if (expired.Count > 0)
                {
                    await db.SaveChangesAsync(stoppingToken);
                    var notifications = scope.ServiceProvider.GetRequiredService<INotificationService>();
                    foreach (var membership in expired)
                        await notifications.CreateAsync(new NotificationInsertRequest { Title = $"Membership {membership.Status.ToLowerInvariant()}", Message = membership.Status == "RenewalDue" ? "Your membership renewal requires payment." : "Your membership period has ended.", Type = "Memberships", RecipientUserIds = [membership.UserId] });
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { }
            catch (Exception ex) { logger.LogError(ex, "Membership lifecycle processing failed."); }
            await Task.Delay(TimeSpan.FromHours(1), stoppingToken);
        }
    }
}
