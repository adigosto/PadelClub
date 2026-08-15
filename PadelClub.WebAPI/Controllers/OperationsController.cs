using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PadelClub.Services.Database;

namespace PadelClub.WebAPI.Controllers;

[ApiController]
[Route("Operations")]
[Authorize(Policy = "AdminOnly")]
public sealed class OperationsController(PadelClubContext db) : ControllerBase
{
    [HttpGet("analytics")]
    public async Task<ActionResult<object>> Analytics([FromQuery] DateTime? from, [FromQuery] DateTime? to, CancellationToken ct)
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

    [HttpGet("audit")]
    public async Task<ActionResult<object>> Audit([FromQuery] int? userId, [FromQuery] string? method, [FromQuery] DateTime? from, CancellationToken ct)
    {
        var query = db.AuditLogs.AsNoTracking().AsQueryable();
        if (userId.HasValue) query = query.Where(x => x.UserId == userId);
        if (!string.IsNullOrWhiteSpace(method)) query = query.Where(x => x.Method == method.ToUpper());
        if (from.HasValue) query = query.Where(x => x.CreatedAt >= from);
        return Ok(await query.OrderByDescending(x => x.CreatedAt).Take(1000).Select(x => new { x.Id, x.UserId, x.Method, x.Path, x.StatusCode, x.IpAddress, x.CorrelationId, x.DurationMs, x.CreatedAt }).ToListAsync(ct));
    }
}
