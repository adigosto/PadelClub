using Microsoft.EntityFrameworkCore;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Services.Recommendations;
using PadelClub.Services.Database;
using PadelClub.WebAPI.Authentication;
using static PadelClub.WebAPI.Workflows.WorkflowResults;

namespace PadelClub.WebAPI.Workflows;

public sealed class OperationsWorkflow(
    PadelClubContext db,
    IRecommendationEvaluationService recommendationEvaluation,
    IRecommendationCohortReadinessService recommendationCohortReadiness, ICurrentUser currentUser)
{
    public async Task<WorkflowResult> Analytics(DateTime? from, DateTime? to, CancellationToken ct)
    {
        var end = to ?? DateTime.UtcNow; var start = from ?? end.AddDays(-30);
        if (end <= start || end - start > TimeSpan.FromDays(366)) return BadRequest("Choose a valid range of at most 366 days.");
        var orders = db.Orders.AsNoTracking().Where(x => x.CreatedAt >= start && x.CreatedAt < end && x.Status != "Cancelled");
        var reservations = db.Reservations.AsNoTracking().Where(x => x.CreatedAt >= start && x.CreatedAt < end);
        var payments = db.Payments.AsNoTracking().Where(x => x.CreatedAt >= start && x.CreatedAt < end && (x.Status == "Completed" || x.Status == "PartiallyRefunded" || x.Status == "Refunded"));
        var topProducts = await db.OrderItems.AsNoTracking().Where(x => x.Order.CreatedAt >= start && x.Order.CreatedAt < end && x.Order.Status != "Cancelled")
            .GroupBy(x => new { x.ProductId, x.Product.Name }).Select(x => new { x.Key.ProductId, x.Key.Name, UnitsSold = x.Sum(i => i.Quantity), Revenue = x.Sum(i => i.TotalPrice) })
            .OrderByDescending(x => x.UnitsSold).Take(10).ToListAsync(ct);
        var dailyRevenue = await payments.GroupBy(x => x.PaymentDate.Date).Select(x => new { Date = x.Key, Gross = x.Sum(p => p.Amount), Refunded = x.Sum(p => p.RefundedAmount) })
            .OrderBy(x => x.Date).ToListAsync(ct);
        return Ok(new {
            From = start, To = end,
            Orders = await orders.CountAsync(ct), OrderRevenue = await orders.SumAsync(x => (decimal?)x.TotalAmount, ct) ?? 0,
            Reservations = await reservations.CountAsync(ct), CancelledReservations = await reservations.CountAsync(x => x.Status == "Cancelled", ct),
            PaymentGross = await payments.SumAsync(x => (decimal?)x.Amount, ct) ?? 0, Refunds = await payments.SumAsync(x => (decimal?)x.RefundedAmount, ct) ?? 0,
            ActiveMemberships = await db.Memberships.CountAsync(x => x.Status == "Active" && x.EndDate > DateTime.UtcNow, ct),
            LowStockProducts = await db.Products.CountAsync(x => x.IsActive && x.StockQuantity <= 5, ct), TopProducts = topProducts, DailyRevenue = dailyRevenue
        });
    }

    /// <summary>
    /// Calculates a transient preview of the recommendation ranker against a
    /// fixed historical window. Use the POST runs endpoint to persist immutable
    /// administrative evidence; this GET deliberately recalculates live data.
    /// </summary>

    public async Task<WorkflowResult> RecommendationEvaluation(
        RecommendationEvaluationRequest request,
        CancellationToken ct)
    {
        if (request.CutoffUtc is null || request.EndUtc is null)
            return BadRequest("cutoffUtc and endUtc are required.");

        var cutoff = request.CutoffUtc.Value.ToUniversalTime();
        var end = request.EndUtc.Value.ToUniversalTime();
        if (end <= cutoff || end - cutoff > TimeSpan.FromDays(366))
            return BadRequest("Choose a valid historical window of at most 366 days.");
        if (end > DateTimeOffset.UtcNow)
            return BadRequest("endUtc cannot be in the future.");

        try
        {
            return Ok(await recommendationEvaluation.EvaluateAsync(
                new RecommendationEvaluationRequest
                {
                    CutoffUtc = cutoff,
                    EndUtc = end,
                    K = request.K
                },
                ct));
        }
        catch (ArgumentException exception)
        {
            return BadRequest(exception.Message);
        }
    }

    /// <summary>
    /// Reports aggregate-only collection progress for the provenance-backed
    /// operational recommendation cohort. It does not calculate metrics or
    /// make a quality claim; use the evaluator with an explicit mature window
    /// after this preflight is ready.
    /// </summary>

    public async Task<WorkflowResult> RecommendationCohortReadiness(
        CancellationToken ct) => Ok(await recommendationCohortReadiness.GetReadinessAsync(ct));

    /// <summary>
    /// Records an immutable, aggregate-only operational evaluation snapshot.
    /// The source fingerprint and full aggregate report are persisted; raw
    /// customer interaction tuples are not.
    /// </summary>

    public async Task<WorkflowResult> CreateRecommendationEvaluationRun(
        RecommendationEvaluationRequest request,
        CancellationToken ct)
    {
        if (!TryValidateEvaluationRequest(request, out var validationError))
            return BadRequest(validationError);

        try
        {
            var run = await recommendationEvaluation.CreateRunAsync(CurrentUserId(), request, ct);
            return Created(run);
        }
        catch (ArgumentException exception)
        {
            return BadRequest(exception.Message);
        }
    }

    public async Task<WorkflowResult> GetLatestRecommendationEvaluationRun(
        CancellationToken ct)
    {
        var run = await recommendationEvaluation.GetLatestRunAsync(ct);
        return run is null ? NotFound() : Ok(run);
    }

    public async Task<WorkflowResult> GetRecommendationEvaluationRun(
        Guid runId,
        CancellationToken ct)
    {
        var run = await recommendationEvaluation.GetRunAsync(runId, ct);
        return run is null ? NotFound() : Ok(run);
    }

    public async Task<WorkflowResult> Audit(int? userId, string? method, DateTime? from, CancellationToken ct, string? userName = null)
    {
        var query = db.AuditLogs.AsNoTracking().AsQueryable();
        if (userId.HasValue) query = query.Where(x => x.UserId == userId);
        if (!string.IsNullOrWhiteSpace(userName))
            query = query.Where(x => db.Users.Any(u => u.Id == x.UserId &&
                (u.Username.Contains(userName.Trim()) || (u.FirstName + " " + u.LastName).Contains(userName.Trim()))));
        if (!string.IsNullOrWhiteSpace(method)) query = query.Where(x => x.Method == method.ToUpper());
        if (from.HasValue) query = query.Where(x => x.CreatedAt >= from);
        return Ok(await query.OrderByDescending(x => x.CreatedAt).Take(1000).Select(x => new { x.Id, x.UserId, UserName = db.Users.Where(u => u.Id == x.UserId).Select(u => u.Username).FirstOrDefault(), x.Method, x.Path, x.StatusCode, x.IpAddress, x.CorrelationId, x.DurationMs, x.CreatedAt }).ToListAsync(ct));
    }

    private static bool TryValidateEvaluationRequest(
        RecommendationEvaluationRequest request,
        out string? error)
    {
        if (request.CutoffUtc is null || request.EndUtc is null)
        {
            error = "cutoffUtc and endUtc are required.";
            return false;
        }

        var cutoff = request.CutoffUtc.Value.ToUniversalTime();
        var end = request.EndUtc.Value.ToUniversalTime();
        if (end <= cutoff || end - cutoff > TimeSpan.FromDays(366))
        {
            error = "Choose a valid historical window of at most 366 days.";
            return false;
        }
        if (end > DateTimeOffset.UtcNow)
        {
            error = "endUtc cannot be in the future.";
            return false;
        }
        if (request.K is < 1 or > 12)
        {
            error = "K must be between 1 and 12.";
            return false;
        }

        error = null;
        return true;
    }

    private int CurrentUserId() => currentUser.Id;

}
