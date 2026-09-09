using System.Globalization;
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

public sealed class ReservationNotificationTests
{
    [Theory]
    [InlineData(7, 18, DateTimeKind.Utc, "en-US")]
    [InlineData(7, 18, DateTimeKind.Unspecified, "bs-Latn-BA")]
    [InlineData(1, 19, DateTimeKind.Utc, "en-US")]
    [InlineData(1, 19, DateTimeKind.Unspecified, "bs-Latn-BA")]
    public async Task Booking_notifications_show_20_00_club_time_in_summer_and_winter(
        int month, int utcHour, DateTimeKind kind, string culture)
    {
        var previousCulture = CultureInfo.CurrentCulture;
        try
        {
            CultureInfo.CurrentCulture = CultureInfo.GetCultureInfo(culture);
            await using var db = new PadelClubContext(
                new DbContextOptionsBuilder<PadelClubContext>()
                    .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
                    // This test covers persisted notification text, not transaction semantics.
                    .ConfigureWarnings(warnings => warnings.Ignore(InMemoryEventId.TransactionIgnoredWarning))
                    .Options);
            var player = new User { Username = "notification-player" };
            var waitingPlayer = new User { Username = "waiting-player" };
            var court = new Court { Name = "Notification court", HourlyRate = 25m };
            db.Users.AddRange(player, waitingPlayer);
            db.Courts.Add(court);
            await db.SaveChangesAsync();

            var mapper = new Mapper(new TypeAdapterConfig());
            var notifications = new NotificationService(db, mapper);
            var service = new ReservationService(db, mapper, notifications,
                Options.Create(new BookingOptions { TimeZoneId = "Europe/Sarajevo" }));
            var year = DateTime.UtcNow.Year + 1;
            var start = new DateTime(year, month, 15, utcHour, 0, 0, kind);
            var expectedTime = $"15.{month:00}.{year} 20:00 (club time)";

            var reservation = await service.CreateAsync(new ReservationInsertRequest
            {
                CourtId = court.Id,
                UserId = player.Id,
                StartTime = start,
                EndTime = start.AddHours(1)
            });
            await service.JoinWaitlistAsync(waitingPlayer.Id, new WaitlistRequest
            {
                CourtId = court.Id,
                StartTime = start,
                EndTime = start.AddHours(1)
            });
            db.ChangeTracker.Clear();
            await service.CancelAsync(reservation.Id, player.Id, isAdministrator: false, reason: "Player changed plans");

            var messages = await db.Notifications.ToListAsync();
            Assert.Equal(3, messages.Count);
            Assert.Equal($"Your reservation for Notification court on {expectedTime} is confirmed.",
                Assert.Single(messages, message => message.Title == "Reservation confirmed").Message);
            Assert.Equal($"Reservation #{reservation.Id} scheduled for {expectedTime} was cancelled.",
                Assert.Single(messages, message => message.Title == "Reservation cancelled").Message);
            Assert.Equal($"A waitlisted court slot on {expectedTime} is now available.",
                Assert.Single(messages, message => message.Title == "Court slot available").Message);
            var cancelledReservation = await db.Reservations.SingleAsync();
            Assert.Equal(start, cancelledReservation.StartTime);
            Assert.Equal("Player changed plans", cancelledReservation.CancellationReason);
            var audit = await db.AuditLogs.SingleAsync();
            Assert.Equal(player.Id, audit.UserId);
            Assert.Equal("Reservation", audit.EntityType);
            Assert.Equal(reservation.Id, audit.EntityId);
            Assert.Equal("Cancelled", audit.Action);
            Assert.Equal("Confirmed", audit.PreviousState);
            Assert.Equal("Cancelled", audit.NewState);
            Assert.Equal("Player changed plans", audit.Reason);
        }
        finally
        {
            CultureInfo.CurrentCulture = previousCulture;
        }
    }
}
