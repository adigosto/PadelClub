using PadelClub.Services;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public class BookingConfigurationTests
{
    [Fact]
    public void Default_timezone_observes_Sarajevo_daylight_saving()
    {
        var zone = TimeZoneInfo.FindSystemTimeZoneById(new BookingOptions().TimeZoneId);
        Assert.NotEqual(zone.GetUtcOffset(new DateTime(2026, 1, 15)), zone.GetUtcOffset(new DateTime(2026, 7, 15)));
    }

    [Fact]
    public void Default_slot_length_evenly_divides_an_hour()
    {
        var options = new BookingOptions();
        Assert.Equal(0, 60 % options.SlotMinutes);
        Assert.True(options.OpeningHour < options.ClosingHour);
    }
}
