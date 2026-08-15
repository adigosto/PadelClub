using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using PadelClub.Services.Database;

namespace PadelClub.WebAPI.Notifications;

public sealed class NotificationDeliveryWorker(IServiceScopeFactory scopeFactory, IOptions<NotificationDeliveryOptions> options, ILogger<NotificationDeliveryWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                await ProcessBatchAsync(scope.ServiceProvider, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { }
            catch (Exception ex) { logger.LogError(ex, "Notification outbox processing failed."); }
            await Task.Delay(TimeSpan.FromSeconds(Math.Max(2, options.Value.PollSeconds)), stoppingToken);
        }
    }

    private async Task ProcessBatchAsync(IServiceProvider services, CancellationToken cancellationToken)
    {
        var db = services.GetRequiredService<PadelClubContext>();
        var deliveries = await db.NotificationDeliveries.Include(x => x.Notification).Include(x => x.User)
            .Where(x => (x.Status == "Pending" || x.Status == "Retry") && x.NextAttemptAt <= DateTime.UtcNow)
            .OrderBy(x => x.Id).Take(50).ToListAsync(cancellationToken);
        foreach (var delivery in deliveries)
        {
            try
            {
                delivery.AttemptCount++;
                if (delivery.Channel == "Email")
                    delivery.ProviderMessageId = await services.GetRequiredService<IEmailSender>().SendAsync(delivery.User.Email, delivery.Notification.Title, delivery.Notification.Message, cancellationToken);
                else
                {
                    var devices = await db.PushDevices.Where(x => x.UserId == delivery.UserId && x.IsActive).ToListAsync(cancellationToken);
                    if (devices.Count == 0) { delivery.Status = "Skipped"; delivery.LastError = "No active push device."; continue; }
                    foreach (var device in devices)
                        delivery.ProviderMessageId = await services.GetRequiredService<IPushSender>().SendAsync(device.InstallationId, delivery.Notification.Title, delivery.Notification.Message,
                            new Dictionary<string, string> { ["notificationId"] = delivery.NotificationId.ToString(), ["type"] = delivery.Notification.Type }, cancellationToken);
                }
                delivery.Status = "Sent";
                delivery.SentAt = DateTime.UtcNow;
                delivery.LastError = null;
            }
            catch (Exception ex)
            {
                delivery.LastError = ex.Message.Length > 2000 ? ex.Message[..2000] : ex.Message;
                delivery.Status = delivery.AttemptCount >= options.Value.MaxAttempts ? "Failed" : "Retry";
                delivery.NextAttemptAt = DateTime.UtcNow.AddMinutes(Math.Pow(2, delivery.AttemptCount));
            }
            finally { await db.SaveChangesAsync(cancellationToken); }
        }
    }
}
