using Microsoft.EntityFrameworkCore;
using PadelClub.Services.Database;
using PadelClub.Model.Requests;
using PadelClub.WebAPI.Authentication;
using static PadelClub.WebAPI.Workflows.WorkflowResults;

namespace PadelClub.WebAPI.Workflows;

public sealed class NotificationSettingsWorkflow(PadelClubContext db, ICurrentUser currentUser)
{
    public async Task<WorkflowResult> Mine(CancellationToken cancellationToken)
    {
        var userId = CurrentUserId();
        var item = await db.NotificationPreferences.SingleOrDefaultAsync(x => x.UserId == userId, cancellationToken);
        return Ok(ToResponse(item));
    }

    public async Task<WorkflowResult> SaveMine(NotificationPreferenceRequest request, CancellationToken cancellationToken)
    {
        var userId = CurrentUserId();
        var item = await db.NotificationPreferences.SingleOrDefaultAsync(x => x.UserId == userId, cancellationToken);
        if (item is null)
        {
            item = new NotificationPreference { UserId = userId };
            db.NotificationPreferences.Add(item);
        }
        item.InAppEnabled = request.InAppEnabled;
        item.EmailEnabled = request.EmailEnabled;
        item.PushEnabled = request.PushEnabled;
        item.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(cancellationToken);
        return Ok(ToResponse(item));
    }

    public async Task<WorkflowResult> RegisterDevice(PushDeviceRequest request, CancellationToken cancellationToken)
    {
        var installationId = request.InstallationId.Trim();
        var platform = request.Platform.Trim().ToLowerInvariant();
        if (installationId.Length is < 10 or > 500 || platform is not ("android" or "ios"))
            return BadRequest("A valid Firebase installation ID and platform (android or ios) are required.");
        var device = await db.PushDevices.SingleOrDefaultAsync(x => x.InstallationId == installationId, cancellationToken);
        if (device is null)
        {
            device = new PushDevice { UserId = CurrentUserId(), InstallationId = installationId, Platform = platform };
            db.PushDevices.Add(device);
        }
        else
        {
            device.UserId = CurrentUserId(); device.Platform = platform; device.IsActive = true; device.LastSeenAt = DateTime.UtcNow;
        }
        await db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    public async Task<WorkflowResult> UnregisterDevice(string installationId, CancellationToken cancellationToken)
    {
        var device = await db.PushDevices.SingleOrDefaultAsync(x => x.UserId == CurrentUserId() && x.InstallationId == installationId, cancellationToken);
        if (device is null) return NotFound();
        device.IsActive = false;
        await db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }


    public async Task<WorkflowResult> Deliveries(string? status, CancellationToken cancellationToken)
    {
        var query = db.NotificationDeliveries.AsNoTracking().AsQueryable();
        if (!string.IsNullOrWhiteSpace(status)) query = query.Where(x => x.Status == status);
        var rows = await query.OrderByDescending(x => x.Id).Take(200)
            .Select(x => new { x.Id, x.NotificationId, x.UserId, x.Channel, x.Status, x.AttemptCount, x.NextAttemptAt, x.SentAt, x.LastError })
            .ToListAsync(cancellationToken);
        return Ok(rows);
    }

    private int CurrentUserId() => currentUser.Id;

    private static NotificationPreferenceResponse ToResponse(NotificationPreference? item) => item is null
        ? new(true, true, true) : new(item.InAppEnabled, item.EmailEnabled, item.PushEnabled);

}
