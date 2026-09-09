using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.EntityFrameworkCore;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Services.Database;
using PadelClub.WebAPI.Tests.Infrastructure;
using Xunit;

namespace PadelClub.WebAPI.Tests;

[Collection(SqlServerIntegrationCollection.Name)]
public sealed class ReservationAvailabilityContractTests(
    SqlServerIntegrationFixture fixture)
{
    private static readonly JsonSerializerOptions JsonOptions = new(
        JsonSerializerDefaults.Web);

    [Theory]
    [InlineData(7, 18)]
    [InlineData(1, 19)]
    public async Task Saved_booking_and_waitlist_times_keep_UTC_markers_after_SQL_reload(
        int month, int utcHour)
    {
        var startUtc = new DateTime(DateTime.UtcNow.Year + 1, month, 15, utcHour, 0, 0, DateTimeKind.Utc);
        int courtId;
        using (var scope = fixture.Api.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
            var court = new Court { Name = $"Booking time contract {Guid.NewGuid():N}", HourlyRate = 25m };
            db.Courts.Add(court);
            await db.SaveChangesAsync();
            courtId = court.Id;
        }

        using var client = fixture.Api.CreateClient(new WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri("https://localhost")
        });
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer", fixture.PlayerSession.AccessToken);
        var created = await client.PostAsJsonAsync("/Reservations", new ReservationInsertRequest
        {
            CourtId = courtId,
            StartTime = startUtc,
            EndTime = startUtc.AddHours(1)
        });
        created.EnsureSuccessStatusCode();
        using var createdJson = JsonDocument.Parse(await created.Content.ReadAsStringAsync());
        var reservationId = createdJson.RootElement.GetProperty("id").GetInt32();
        AssertUtcInterval(createdJson.RootElement, startUtc, "startTime", "endTime");

        using (var scope = fixture.Api.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
            var stored = await db.Reservations.AsNoTracking().SingleAsync(row => row.Id == reservationId);
            Assert.Equal(DateTimeKind.Unspecified, stored.StartTime.Kind);
            Assert.Equal(startUtc.Ticks, stored.StartTime.Ticks);
            db.WaitlistEntries.Add(new WaitlistEntry
            {
                CourtId = courtId,
                UserId = fixture.Api.Seed.PlayerUserId,
                StartTimeUtc = startUtc,
                EndTimeUtc = startUtc.AddHours(1)
            });
            await db.SaveChangesAsync();
        }

        foreach (var path in new[] { "/Reservations/mine?PageSize=1000", $"/Reservations/{reservationId}" })
        {
            using var json = JsonDocument.Parse(await client.GetStringAsync(path));
            var booking = json.RootElement.TryGetProperty("items", out var items)
                ? items.EnumerateArray().Single(row => row.GetProperty("id").GetInt32() == reservationId)
                : json.RootElement;
            AssertUtcInterval(booking, startUtc, "startTime", "endTime");
        }
        using var waitlistJson = JsonDocument.Parse(await client.GetStringAsync("/Reservations/waitlist/mine"));
        var entry = waitlistJson.RootElement.EnumerateArray()
            .Single(row => row.GetProperty("courtId").GetInt32() == courtId);
        AssertUtcInterval(entry, startUtc, "startTimeUtc", "endTimeUtc");

        var cancelled = await client.PutAsJsonAsync(
            $"/Reservations/{reservationId}/cancel",
            new CancelReservationRequest { Reason = "Contract test cancellation" });
        cancelled.EnsureSuccessStatusCode();
        using var cancelledJson = JsonDocument.Parse(await cancelled.Content.ReadAsStringAsync());
        AssertUtcInterval(cancelledJson.RootElement, startUtc, "startTime", "endTime");
        Assert.EndsWith("Z", cancelledJson.RootElement.GetProperty("cancelledAt").GetString());
        Assert.EndsWith("Z", cancelledJson.RootElement.GetProperty("updatedAt").GetString());
    }

    private static void AssertUtcInterval(JsonElement value, DateTime startUtc, string startKey, string endKey)
    {
        Assert.EndsWith("Z", value.GetProperty(startKey).GetString());
        Assert.EndsWith("Z", value.GetProperty(endKey).GetString());
        var parsedStart = value.GetProperty(startKey).GetDateTime();
        Assert.Equal(DateTimeKind.Utc, parsedStart.Kind);
        Assert.Equal(startUtc, parsedStart);
        Assert.Equal(startUtc.AddHours(1), value.GetProperty(endKey).GetDateTime());
        Assert.Equal(20, TimeZoneInfo.ConvertTimeFromUtc(parsedStart,
            TimeZoneInfo.FindSystemTimeZoneById("Europe/Sarajevo")).Hour);
    }

    [Fact]
    public async Task Availability_marks_only_future_reservation_conflicts_as_waitlist_eligible()
    {
        var zone = TimeZoneInfo.FindSystemTimeZoneById("Europe/Sarajevo");
        var localDate = TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, zone)
            .Date
            .AddDays(2);
        var reservationStartUtc = TimeZoneInfo.ConvertTimeToUtc(
            DateTime.SpecifyKind(localDate.AddHours(10), DateTimeKind.Unspecified),
            zone);
        var maintenanceStartUtc = reservationStartUtc.AddHours(1);
        int courtId;

        using (var scope = fixture.Api.Services.CreateScope())
        {
            var database = scope.ServiceProvider.GetRequiredService<PadelClubContext>();
            var court = new Court
            {
                Name = $"Waitlist contract court {Guid.NewGuid():N}",
                Description = "Availability contract test court",
                IsActive = true,
                IsIndoor = true,
                HourlyRate = 28m,
                MaxPlayers = 4
            };
            database.Courts.Add(court);
            await database.SaveChangesAsync();
            courtId = court.Id;

            database.Reservations.Add(new Reservation
            {
                CourtId = courtId,
                UserId = fixture.Api.Seed.PlayerUserId,
                StartTime = reservationStartUtc,
                EndTime = reservationStartUtc.AddHours(1),
                TotalPrice = 28m,
                Status = "Confirmed"
            });
            database.MaintenanceBlocks.Add(new MaintenanceBlock
            {
                CourtId = courtId,
                StartTimeUtc = maintenanceStartUtc,
                EndTimeUtc = maintenanceStartUtc.AddHours(1),
                Reason = "Availability contract test maintenance"
            });
            await database.SaveChangesAsync();
        }

        using var client = fixture.Api.CreateClient(new WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri("https://localhost")
        });
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            fixture.PlayerSession.AccessToken);
        var response = await client.GetAsync(
            $"/Reservations/availability?date={localDate:yyyy-MM-dd}");
        response.EnsureSuccessStatusCode();

        var courts = await response.Content.ReadFromJsonAsync<
            List<CourtAvailabilityResponse>>(JsonOptions);
        var slots = Assert.Single(courts!, court => court.CourtId == courtId).Slots;
        var reservationSlot = Assert.Single(
            slots,
            slot => slot.StartTime.ToUniversalTime() == reservationStartUtc);
        var maintenanceSlot = Assert.Single(
            slots,
            slot => slot.StartTime.ToUniversalTime() == maintenanceStartUtc);

        Assert.False(reservationSlot.IsAvailable);
        Assert.True(reservationSlot.IsWaitlistEligible);
        Assert.False(maintenanceSlot.IsAvailable);
        Assert.False(maintenanceSlot.IsWaitlistEligible);
    }
}
