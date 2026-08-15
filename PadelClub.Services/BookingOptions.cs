namespace PadelClub.Services;

public sealed class BookingOptions
{
    public const string SectionName = "Booking";
    public string TimeZoneId { get; set; } = "Europe/Sarajevo";
    public int OpeningHour { get; set; } = 7;
    public int ClosingHour { get; set; } = 23;
    public int SlotMinutes { get; set; } = 60;
    public int CancellationNoticeHours { get; set; } = 2;
    public int MaxRecurringWeeks { get; set; } = 12;
}
