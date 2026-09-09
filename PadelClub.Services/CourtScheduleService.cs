using Microsoft.EntityFrameworkCore;
using PadelClub.Services.Database;

namespace PadelClub.Services;

public sealed record CourtOccupation(int? CourtId, DateTime Start, DateTime End, string Kind)
{
    public bool Overlaps(int courtId, DateTime start, DateTime end) =>
        (!CourtId.HasValue || CourtId == courtId) && Start < end && End > start;
}

public interface ICourtScheduleService
{
    Task LockCourtsAsync(int? courtId = null, CancellationToken ct = default);
    Task<List<CourtOccupation>> GetOccupationsAsync(DateTime start, DateTime end, int? ignoredReservationId = null, CancellationToken ct = default);
    Task RequireAvailableAsync(int courtId, DateTime start, DateTime end, int? ignoredReservationId = null, CancellationToken ct = default);
}

public sealed class CourtScheduleService(PadelClubContext db) : ICourtScheduleService
{
    // Tournament scheduling reserves a full hour, including warm-up and changeover.
    public const int MatchMinutes = 60;

    public async Task LockCourtsAsync(int? courtId = null, CancellationToken ct = default)
    {
        if (!db.Database.IsSqlServer()) return;
        if (db.Database.CurrentTransaction is null)
            throw new InvalidOperationException("Court scheduling requires a transaction.");
        var query = courtId.HasValue
            ? db.Courts.FromSqlInterpolated($"SELECT * FROM [Courts] WITH (UPDLOCK, HOLDLOCK) WHERE [Id] = {courtId.Value}")
            : db.Courts.FromSqlRaw("SELECT * FROM [Courts] WITH (UPDLOCK, HOLDLOCK) ORDER BY [Id]");
        await query.AsNoTracking().ToListAsync(ct);
    }

    public async Task<List<CourtOccupation>> GetOccupationsAsync(DateTime start, DateTime end, int? ignoredReservationId = null, CancellationToken ct = default)
    {
        var result = await db.Reservations.AsNoTracking()
            .Where(x => x.Id != ignoredReservationId && x.Status != "Cancelled" && x.StartTime < end && x.EndTime > start)
            .Select(x => new CourtOccupation(x.CourtId, x.StartTime, x.EndTime, "reservation")).ToListAsync(ct);
        result.AddRange(await db.Matches.AsNoTracking()
            .Where(x => !x.IsBye && x.Status != "Cancelled" && x.ScheduledTime < end && x.ScheduledTime.AddMinutes(MatchMinutes) > start)
            .Select(x => new CourtOccupation(x.CourtId, x.ScheduledTime, x.ScheduledTime.AddMinutes(MatchMinutes), "tournament match")).ToListAsync(ct));
        result.AddRange(await db.MaintenanceBlocks.AsNoTracking()
            .Where(x => x.IsActive && x.StartTimeUtc < end && x.EndTimeUtc > start)
            .Select(x => new CourtOccupation(x.CourtId, x.StartTimeUtc, x.EndTimeUtc, "maintenance")).ToListAsync(ct));
        return result;
    }

    public async Task RequireAvailableAsync(int courtId, DateTime start, DateTime end, int? ignoredReservationId = null, CancellationToken ct = default)
    {
        var busy = (await GetOccupationsAsync(start, end, ignoredReservationId, ct)).FirstOrDefault(x => x.Overlaps(courtId, start, end));
        if (busy is not null) throw new InvalidOperationException($"The court is unavailable due to an existing {busy.Kind}.");
    }
}
