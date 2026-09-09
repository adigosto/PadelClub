using Mapster;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Options;
using PadelClub.Model.Requests;
using PadelClub.Services;
using PadelClub.Services.Database;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public class RecurringReservationBatchTests
{
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Series_checks_schedule_once_and_never_saves_a_partial_series(bool conflict)
    {
        var saves = new SaveCounter();
        await using var db = new PadelClubContext(new DbContextOptionsBuilder<PadelClubContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .ConfigureWarnings(x => x.Ignore(InMemoryEventId.TransactionIgnoredWarning))
            .AddInterceptors(saves).Options);
        var user = new User { Username = "recurring" };
        var court = new Court { Name = "Recurring court", HourlyRate = 25 };
        db.AddRange(user, court);
        await db.SaveChangesAsync();
        saves.Count = 0;
        var start = new DateTime(DateTime.UtcNow.Year + 1, 7, 1, 10, 0, 0, DateTimeKind.Utc);
        var schedule = new Schedule(conflict ? [new CourtOccupation(court.Id, start.AddDays(14), start.AddDays(14).AddHours(1), "maintenance")] : []);
        var mapper = new Mapper(new TypeAdapterConfig());
        var service = new ReservationService(db, mapper, new NotificationService(db, mapper),
            Options.Create(new BookingOptions { TimeZoneId = "Europe/Sarajevo" }), schedule);
        var request = new RecurringReservationRequest { CourtId = court.Id, StartTime = start, EndTime = start.AddHours(1), Weeks = 4 };
        if (conflict)
        {
            await Assert.ThrowsAsync<InvalidOperationException>(() => service.CreateRecurringAsync(user.Id, request));
            Assert.Empty(await db.Reservations.ToListAsync());
            Assert.Equal(0, saves.Count);
        }
        else
        {
            var result = await service.CreateRecurringAsync(user.Id, request);
            Assert.Equal(4, result.Count);
            Assert.All(result, item => Assert.Equal(25m, item.TotalPrice));
            Assert.Single((await db.Reservations.ToListAsync()).Select(x => x.SeriesId).Distinct());
            Assert.Equal(2, saves.Count); // One batch, then its notification.
        }
        Assert.Equal(1, schedule.Reads);
    }

    private sealed class SaveCounter : SaveChangesInterceptor
    {
        public int Count;
        public override ValueTask<InterceptionResult<int>> SavingChangesAsync(DbContextEventData eventData,
            InterceptionResult<int> result, CancellationToken cancellationToken = default)
        { Count++; return ValueTask.FromResult(result); }
    }

    private sealed class Schedule(List<CourtOccupation> occupations) : ICourtScheduleService
    {
        public int Reads;
        public Task LockCourtsAsync(int? courtId = null, CancellationToken ct = default) => Task.CompletedTask;
        public Task<List<CourtOccupation>> GetOccupationsAsync(DateTime start, DateTime end, int? ignoredReservationId = null, CancellationToken ct = default)
        { Reads++; return Task.FromResult(occupations); }
        public Task RequireAvailableAsync(int courtId, DateTime start, DateTime end, int? ignoredReservationId = null, CancellationToken ct = default) => throw new NotSupportedException();
    }
}
