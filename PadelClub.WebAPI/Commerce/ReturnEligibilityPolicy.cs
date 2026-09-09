namespace PadelClub.WebAPI.Commerce;

/// <summary>
/// Centralizes the customer return window so every customer-facing return
/// operation uses the same deadline calculation.
/// </summary>
internal static class ReturnEligibilityPolicy
{
    internal static readonly TimeSpan ReturnWindow = TimeSpan.FromDays(30);

    internal static DateTime ReturnWindowEndsAt(DateTime deliveredAt) =>
        deliveredAt.Add(ReturnWindow);

    internal static DateTime EarliestEligibleDeliveredAt(DateTime utcNow) =>
        utcNow.Subtract(ReturnWindow);

    internal static bool IsEligible(string status, DateTime? deliveredAt, DateTime utcNow) =>
        string.Equals(status, "Delivered", StringComparison.Ordinal) &&
        deliveredAt is { } deliveredAtUtc &&
        // A delivery timestamp is evidence of completed fulfilment, not a
        // scheduled delivery estimate. Future timestamps must therefore never
        // make an order returnable, even though they fall before a calculated
        // return-window end date.
        deliveredAtUtc <= utcNow &&
        utcNow <= ReturnWindowEndsAt(deliveredAtUtc);
}
