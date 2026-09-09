using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.EntityFrameworkCore;
using PadelClub.Model.Responses;
using PadelClub.Services.Database;

namespace PadelClub.Services.Recommendations;

/// <summary>
/// Produces an aggregate descriptive funnel for server-recorded impressions.
/// It intentionally has no control group, so it never reports causal lift.
/// </summary>
public sealed class RecommendationImpactService(PadelClubContext db) : IRecommendationImpactService
{
    public async Task<RecommendationImpactResponse> GetAsync(
        DateTimeOffset fromUtc,
        DateTimeOffset toUtc,
        CancellationToken cancellationToken = default)
    {
        var from = fromUtc.UtcDateTime;
        var to = toUtc.UtcDateTime;
        var rows = await db.RecommendationExposures
            .AsNoTracking()
            .Where(item => item.ServedAtUtc >= from && item.ServedAtUtc < to)
            .Select(item => new ImpactRow(
                item.UserId,
                item.TelemetrySource,
                item.ServedAtUtc,
                item.ClickedAtUtc,
                item.PurchasedOrderId,
                item.PurchasedAtUtc,
                item.PurchasedOrder == null ? null : item.PurchasedOrder.Status,
                item.PurchasedOrder == null ? null : item.PurchasedOrder.TotalAmount,
                item.PurchasedOrder == null ? null : item.PurchasedOrder.Origin,
                item.PurchasedOrder != null && item.PurchasedOrder.IsSeededForDemo))
            .ToListAsync(cancellationToken);

        // Telemetry provenance is captured when an exposure is served, not
        // reconstructed from a client-provided label later. Mature counts are
        // intentionally restricted to production verified-player sessions.
        var operationalRows = rows
            .Where(item => item.TelemetrySource == RecommendationTelemetrySource.OperationalCustomer)
            .ToArray();
        var excludedNonOperationalExposures = rows.Count - operationalRows.Length;
        var invalidClickTimingExposures = operationalRows.Count(item =>
            item.ClickedAtUtc is not null &&
            !RecommendationImpactPolicy.HasValidClickTiming(item.ServedAtUtc, item.ClickedAtUtc));
        var validClickedRows = operationalRows
            .Where(item => RecommendationImpactPolicy.HasValidClickTiming(item.ServedAtUtc, item.ClickedAtUtc))
            .ToArray();
        var exposures = operationalRows.Length;
        var distinctUsers = operationalRows.Select(item => item.UserId).Distinct().Count();
        var clicked = validClickedRows.Length;
        // One order can legitimately contain several recommended products.
        // Group before reporting orders or revenue so the checkout is never
        // counted once per line-level exposure.
        var attributedOrders = validClickedRows
            .Where(IsOperationalAttribution)
            .GroupBy(item => item.PurchasedOrderId!.Value)
            .Select(group => group.First())
            .ToArray();
        var checkout = attributedOrders.Length;
        var delivered = attributedOrders
            .Where(item => item.PurchasedOrderStatus == "Delivered")
            .ToArray();
        var cancelled = attributedOrders.Count(item => item.PurchasedOrderStatus == "Cancelled");
        var observationDays = operationalRows.Length == 0
            ? 0
            : Math.Max(0, (int)Math.Floor((to - operationalRows.Min(item => item.ServedAtUtc)).TotalDays));

        var unmet = new List<string>();
        if (exposures < RecommendationImpactPolicy.MinimumExposures)
            unmet.Add($"At least {RecommendationImpactPolicy.MinimumExposures} server-recorded exposures are required; {exposures} are in the selected window.");
        if (distinctUsers < RecommendationImpactPolicy.MinimumDistinctUsers)
            unmet.Add($"At least {RecommendationImpactPolicy.MinimumDistinctUsers} distinct players are required; {distinctUsers} are in the selected window.");
        if (observationDays < RecommendationImpactPolicy.MinimumObservationDays)
            unmet.Add($"At least {RecommendationImpactPolicy.MinimumObservationDays} observation days are required; {observationDays} are covered.");
        if (to > DateTime.UtcNow.AddDays(-RecommendationImpactPolicy.AttributionWindowDays))
            unmet.Add($"The selected window must end at least {RecommendationImpactPolicy.AttributionWindowDays} days ago so checkout attribution can mature.");

        var limitations = new List<string>
        {
            "This is descriptive telemetry for authenticated player sessions, not a randomized experiment or a causal-impact estimate.",
            "A checkout is attributed only when the same player clicked the server-issued exposure for the same product within the seven-day attribution window.",
            "Delivered conversion and attributed revenue exclude pending, shipped, and cancelled orders; return-adjusted net revenue is not yet modeled here.",
            "Only production, active, email-verified Player sessions without an Administrator role can enter the operational funnel. Demo, integration-test, admin, unverified, and non-production sources are aggregate-excluded.",
            "Recommendation exposures can be generated from demo serving history during local demonstration, but an online result is not operational evidence until real customer traffic meets every maturity gate."
        };
        if (excludedNonOperationalExposures > 0)
        {
            limitations.Add(
                $"{excludedNonOperationalExposures} non-operational exposure(s) in the selected window were excluded from every funnel metric and maturity gate.");
        }
        if (invalidClickTimingExposures > 0)
        {
            limitations.Add(
                $"{invalidClickTimingExposures} operational exposure(s) had an invalid click timestamp and were excluded from click and conversion metrics.");
        }

        return new RecommendationImpactResponse
        {
            FromUtc = fromUtc.ToUniversalTime(),
            ToUtc = toUtc.ToUniversalTime(),
            EvidenceTier = unmet.Count == 0 ? "Descriptive" : "Collecting",
            IsMature = unmet.Count == 0,
            AttributionWindowDays = RecommendationImpactPolicy.AttributionWindowDays,
            MinimumObservationDays = RecommendationImpactPolicy.MinimumObservationDays,
            MinimumExposures = RecommendationImpactPolicy.MinimumExposures,
            MinimumDistinctUsers = RecommendationImpactPolicy.MinimumDistinctUsers,
            Exposures = exposures,
            ExcludedNonOperationalExposures = excludedNonOperationalExposures,
            DistinctUsers = distinctUsers,
            ClickedExposures = clicked,
            InvalidClickTimingExposures = invalidClickTimingExposures,
            AttributedCheckouts = checkout,
            AttributedDeliveredOrders = delivered.Length,
            AttributedCancelledOrders = cancelled,
            AttributedDeliveredRevenue = delivered.Sum(item => item.PurchasedOrderTotalAmount ?? 0m),
            ClickThroughRate = Rate(clicked, exposures),
            CheckoutConversionRate = Rate(checkout, exposures),
            DeliveredConversionRate = Rate(delivered.Length, exposures),
            ObservationDays = observationDays,
            UnmetRequirements = unmet,
            Limitations = limitations
        };
    }

    private static bool IsOperationalAttribution(ImpactRow row) =>
        row.PurchasedOrderId is not null &&
        row.PurchasedOrderOrigin == OrderOrigin.CustomerCheckout &&
        !row.PurchasedOrderIsSeededForDemo &&
        RecommendationImpactPolicy.HasValidAttributionTiming(
            row.ServedAtUtc,
            row.ClickedAtUtc,
            row.PurchasedAtUtc);

    private static double? Rate(int numerator, int denominator) =>
        denominator == 0 ? null : (double)numerator / denominator;

    private sealed record ImpactRow(
        int UserId,
        RecommendationTelemetrySource TelemetrySource,
        DateTime ServedAtUtc,
        DateTime? ClickedAtUtc,
        int? PurchasedOrderId,
        DateTime? PurchasedAtUtc,
        string? PurchasedOrderStatus,
        decimal? PurchasedOrderTotalAmount,
        OrderOrigin? PurchasedOrderOrigin,
        bool PurchasedOrderIsSeededForDemo);
}
