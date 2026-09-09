namespace PadelClub.Services;

public static class ReservationLifecycle
{
    public static void RequireTransition(string current, string next, DateTime endTime, DateTime now)
    {
        var allowed = (current, next) switch
        {
            ("Pending", "Confirmed" or "Cancelled") => true,
            ("Confirmed", "Cancelled") => true,
            ("Confirmed", "Completed" or "NoShow") => endTime <= now,
            _ => false
        };
        if (!allowed)
            throw new InvalidOperationException("This reservation cannot make the requested status transition.");
    }
}
