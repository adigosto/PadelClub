using Microsoft.EntityFrameworkCore;
using PadelClub.Services.Database;

namespace PadelClub.WebAPI.Privacy;

public sealed class PrivacyDeletionWorker(IServiceScopeFactory scopeFactory, ILogger<PrivacyDeletionWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
                var requests = await db.PrivacyRequests.Include(x => x.User).Where(x => x.Status == "Scheduled" && x.ScheduledFor <= DateTime.UtcNow).OrderBy(x => x.ScheduledFor).Take(50).ToListAsync(stoppingToken);
                foreach (var request in requests)
                {
                    var marker = $"deleted-{request.UserId}-{Guid.NewGuid():N}";
                    request.User.Username = marker; request.User.Email = $"{marker}@deleted.invalid"; request.User.FirstName = "Deleted"; request.User.LastName = "User";
                    request.User.PhoneNumber = null; request.User.PasswordHash = "DELETED"; request.User.PasswordSalt = "DELETED"; request.User.IsActive = false; request.User.UpdatedAt = DateTime.UtcNow;
                    await db.AuthTokens.Where(x => x.UserId == request.UserId).ExecuteDeleteAsync(stoppingToken);
                    await db.PushDevices.Where(x => x.UserId == request.UserId).ExecuteDeleteAsync(stoppingToken);
                    await db.PlayerProfiles.Where(x => x.UserId == request.UserId).ExecuteUpdateAsync(x => x.SetProperty(p => p.IsDiscoverable, false).SetProperty(p => p.Bio, string.Empty).SetProperty(p => p.Availability, string.Empty), stoppingToken);
                    await db.Orders.Where(x => x.UserId == request.UserId).ExecuteUpdateAsync(x => x.SetProperty(o => o.RecipientName, "Deleted User").SetProperty(o => o.PhoneNumber, "redacted")
                        .SetProperty(o => o.ShippingAddress, "redacted").SetProperty(o => o.City, "redacted").SetProperty(o => o.PostalCode, "redacted").SetProperty(o => o.Notes, (string?)null), stoppingToken);
                    await db.ReturnRequests.Where(x => x.UserId == request.UserId).ExecuteUpdateAsync(x => x.SetProperty(r => r.Reason, "redacted").SetProperty(r => r.AdminNotes, (string?)null), stoppingToken);
                    await db.PartnerInvitations.Where(x => x.SenderUserId == request.UserId || x.RecipientUserId == request.UserId).ExecuteUpdateAsync(x => x.SetProperty(i => i.Message, string.Empty), stoppingToken);
                    await db.ClubReviews.Where(x => x.UserId == request.UserId).ExecuteUpdateAsync(x => x.SetProperty(r => r.Comment, string.Empty).SetProperty(r => r.IsPublished, false), stoppingToken);
                    await db.AuditLogs.Where(x => x.UserId == request.UserId).ExecuteUpdateAsync(x => x.SetProperty(a => a.UserId, (int?)null).SetProperty(a => a.IpAddress, "redacted"), stoppingToken);
                    request.Status = "Completed"; request.CompletedAt = DateTime.UtcNow;
                    await db.SaveChangesAsync(stoppingToken);
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { }
            catch (Exception ex) { logger.LogError(ex, "Privacy deletion processing failed."); }
            await Task.Delay(TimeSpan.FromHours(1), stoppingToken);
        }
    }
}
