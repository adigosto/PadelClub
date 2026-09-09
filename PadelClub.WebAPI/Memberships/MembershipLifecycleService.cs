using Microsoft.EntityFrameworkCore;
using PadelClub.Services.Database;

namespace PadelClub.WebAPI.Memberships;

public sealed class MembershipLifecycleService(PadelClubContext database) : IMembershipLifecycleService
{
    public Task<Membership?> GetOwnedAsync(int id, int userId, CancellationToken cancellationToken) =>
        database.Memberships.Include(x => x.Events).SingleOrDefaultAsync(x => x.Id == id && x.UserId == userId, cancellationToken);

    public Task<Membership?> GetAsync(int id, CancellationToken cancellationToken) =>
        database.Memberships.Include(x => x.Events).SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

    public Task<List<MembershipEvent>> GetHistoryAsync(int id, CancellationToken cancellationToken) =>
        database.MembershipEvents.AsNoTracking().Where(x => x.MembershipId == id).OrderByDescending(x => x.CreatedAt).ToListAsync(cancellationToken);

    public async Task CancelAtPeriodEndAsync(Membership membership, CancellationToken cancellationToken)
    {
        membership.CancelAtPeriodEnd = true;
        membership.AutoRenew = false;
        membership.UpdatedAt = DateTime.UtcNow;
        membership.Events.Add(new MembershipEvent { EventType = "CancellationScheduled", Notes = "Cancellation requested for the end of the current period.", ActorUserId = membership.UserId });
        await database.SaveChangesAsync(cancellationToken);
    }

    public async Task SetAutoRenewAsync(Membership membership, bool enabled, CancellationToken cancellationToken)
    {
        membership.AutoRenew = enabled;
        if (enabled) membership.CancelAtPeriodEnd = false;
        membership.UpdatedAt = DateTime.UtcNow;
        membership.Events.Add(new MembershipEvent { EventType = "AutoRenewChanged", Notes = enabled ? "Automatic renewal enabled." : "Automatic renewal disabled.", ActorUserId = membership.UserId });
        await database.SaveChangesAsync(cancellationToken);
    }

    public async Task ChangeStatusAsync(Membership membership, string status, string? notes, int actorUserId, CancellationToken cancellationToken)
    {
        if (status == "Active" && membership.EndDate <= DateTime.UtcNow)
            throw new InvalidOperationException("An expired membership must be renewed before it can be activated.");
        membership.Status = status;
        membership.IsActive = status == "Active";
        membership.UpdatedAt = DateTime.UtcNow;
        membership.SuspendedAt = status == "Suspended" ? DateTime.UtcNow : null;
        membership.CancelledAt = status == "Cancelled" ? DateTime.UtcNow : null;
        if (status == "Cancelled") { membership.AutoRenew = false; membership.CancelAtPeriodEnd = false; }
        membership.Events.Add(new MembershipEvent { EventType = status, Notes = string.IsNullOrWhiteSpace(notes) ? $"Membership changed to {status}." : notes.Trim(), ActorUserId = actorUserId });
        await database.SaveChangesAsync(cancellationToken);
    }

    public async Task RenewAsync(Membership membership, int months, int actorUserId, CancellationToken cancellationToken)
    {
        var payment = await database.Payments.AsNoTracking().SingleOrDefaultAsync(
            x => x.MembershipId == membership.Id && x.Status == "Completed" && x.Amount >= membership.Price * months,
            cancellationToken);
        if (payment is null)
            throw new InvalidOperationException("Membership renewal requires a confirmed payment for the requested period.");

        var from = membership.EndDate > DateTime.UtcNow ? membership.EndDate : DateTime.UtcNow;
        membership.EndDate = from.AddMonths(months);
        membership.Status = "Active";
        membership.IsActive = true;
        membership.CancelAtPeriodEnd = false;
        membership.CancelledAt = null;
        membership.SuspendedAt = null;
        membership.UpdatedAt = DateTime.UtcNow;
        membership.Events.Add(new MembershipEvent { EventType = "Renewed", Notes = $"Membership renewed for {months} month(s). Payment #{payment.Id} confirmed.", ActorUserId = actorUserId });
        await database.SaveChangesAsync(cancellationToken);
    }
}