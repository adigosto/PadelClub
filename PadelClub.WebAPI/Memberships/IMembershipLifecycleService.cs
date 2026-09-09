using PadelClub.Services.Database;

namespace PadelClub.WebAPI.Memberships;

public interface IMembershipLifecycleService
{
    Task<Membership?> GetOwnedAsync(int id, int userId, CancellationToken cancellationToken);
    Task<Membership?> GetAsync(int id, CancellationToken cancellationToken);
    Task<List<MembershipEvent>> GetHistoryAsync(int id, CancellationToken cancellationToken);
    Task CancelAtPeriodEndAsync(Membership membership, CancellationToken cancellationToken);
    Task SetAutoRenewAsync(Membership membership, bool enabled, CancellationToken cancellationToken);
    Task ChangeStatusAsync(Membership membership, string status, string? notes, int actorUserId, CancellationToken cancellationToken);
    Task RenewAsync(Membership membership, int months, int actorUserId, CancellationToken cancellationToken);
}