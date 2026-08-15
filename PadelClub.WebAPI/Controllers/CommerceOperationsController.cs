using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PadelClub.Model.Requests;
using PadelClub.Services;
using PadelClub.Services.Database;
using PadelClub.WebAPI.Payments;

namespace PadelClub.WebAPI.Controllers;

[ApiController]
[Route("Commerce")]
[Authorize]
public sealed class CommerceOperationsController(PadelClubContext db, IStripePaymentService stripe, INotificationService notifications) : ControllerBase
{
    [HttpPost("inventory/{productId:int}/adjust")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<IActionResult> AdjustInventory(int productId, InventoryAdjustmentRequest request, CancellationToken ct)
    {
        if (request.QuantityChange == 0 || Math.Abs(request.QuantityChange) > 10000 || request.Reason.Trim().Length is < 3 or > 200) return BadRequest("A valid quantity change and reason are required.");
        await using var transaction = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable, ct);
        var product = await db.Products.SingleOrDefaultAsync(x => x.Id == productId, ct);
        if (product is null) return NotFound();
        if (product.StockQuantity + request.QuantityChange < 0) return Conflict("Inventory cannot become negative.");
        product.StockQuantity += request.QuantityChange;
        db.InventoryMovements.Add(new InventoryMovement { ProductId = productId, QuantityChange = request.QuantityChange, BalanceAfter = product.StockQuantity, Reason = request.Reason.Trim(), ReferenceType = "Adjustment", ActorUserId = CurrentUserId() });
        await db.SaveChangesAsync(ct); await transaction.CommitAsync(ct);
        return NoContent();
    }

    [HttpGet("inventory/{productId:int}/history")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<ActionResult<object>> InventoryHistory(int productId, CancellationToken ct) => Ok(await db.InventoryMovements.AsNoTracking().Where(x => x.ProductId == productId)
        .OrderByDescending(x => x.CreatedAt).Take(500).Select(x => new { x.Id, x.QuantityChange, x.BalanceAfter, x.Reason, x.ReferenceType, x.ReferenceId, x.ActorUserId, x.CreatedAt }).ToListAsync(ct));

    [HttpPost("coupons")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<ActionResult<object>> CreateCoupon(CouponRequest request, CancellationToken ct)
    {
        var error = ValidateCoupon(request); if (error is not null) return BadRequest(error);
        var code = request.Code.Trim().ToUpperInvariant();
        if (await db.Coupons.AnyAsync(x => x.Code == code, ct)) return Conflict("Coupon code already exists.");
        var coupon = new Coupon { Code = code, DiscountType = CanonicalType(request.DiscountType)!, Value = request.Value, MinimumOrderAmount = request.MinimumOrderAmount,
            MaximumDiscount = request.MaximumDiscount, ValidFrom = request.ValidFrom, ValidUntil = request.ValidUntil, UsageLimit = request.UsageLimit, PerUserLimit = request.PerUserLimit, IsActive = request.IsActive };
        db.Coupons.Add(coupon); await db.SaveChangesAsync(ct);
        return Ok(new { coupon.Id, coupon.Code });
    }

    [HttpPut("coupons/{id:int}")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<IActionResult> UpdateCoupon(int id, CouponRequest request, CancellationToken ct)
    {
        var error = ValidateCoupon(request); if (error is not null) return BadRequest(error);
        var coupon = await db.Coupons.SingleOrDefaultAsync(x => x.Id == id, ct); if (coupon is null) return NotFound();
        var code = request.Code.Trim().ToUpperInvariant();
        if (await db.Coupons.AnyAsync(x => x.Id != id && x.Code == code, ct)) return Conflict("Coupon code already exists.");
        coupon.Code = code; coupon.DiscountType = CanonicalType(request.DiscountType)!; coupon.Value = request.Value; coupon.MinimumOrderAmount = request.MinimumOrderAmount;
        coupon.MaximumDiscount = request.MaximumDiscount; coupon.ValidFrom = request.ValidFrom; coupon.ValidUntil = request.ValidUntil; coupon.UsageLimit = request.UsageLimit;
        coupon.PerUserLimit = request.PerUserLimit; coupon.IsActive = request.IsActive; await db.SaveChangesAsync(ct); return NoContent();
    }

    [HttpGet("coupons")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<ActionResult<object>> Coupons(CancellationToken ct) => Ok(await db.Coupons.AsNoTracking().OrderByDescending(x => x.ValidUntil).Take(500)
        .Select(x => new { x.Id, x.Code, x.DiscountType, x.Value, x.MinimumOrderAmount, x.MaximumDiscount, x.ValidFrom, x.ValidUntil, x.UsageLimit, x.UsageCount, x.PerUserLimit, x.IsActive }).ToListAsync(ct));

    [HttpPost("returns")]
    public async Task<ActionResult<object>> RequestReturn(ReturnCreateRequest request, CancellationToken ct)
    {
        if (request.Reason.Trim().Length is < 5 or > 1000 || request.Items.Count == 0) return BadRequest("A reason and at least one item are required.");
        var userId = CurrentUserId();
        var order = await db.Orders.Include(x => x.OrderItems).Include(x => x.ReturnRequests).ThenInclude(x => x.Items)
            .SingleOrDefaultAsync(x => x.Id == request.OrderId && x.UserId == userId, ct);
        if (order is null) return NotFound();
        if (order.Status != "Delivered" || order.DeliveredAt is null || order.DeliveredAt < DateTime.UtcNow.AddDays(-30)) return Conflict("This order is outside the return window.");
        var quantities = request.Items.GroupBy(x => x.OrderItemId).ToDictionary(x => x.Key, x => x.Sum(i => i.Quantity));
        var lines = new List<ReturnRequestItem>();
        foreach (var pair in quantities)
        {
            var item = order.OrderItems.SingleOrDefault(x => x.Id == pair.Key);
            var alreadyRequested = order.ReturnRequests.Where(x => x.Status != "Rejected").SelectMany(x => x.Items).Where(x => x.OrderItemId == pair.Key).Sum(x => x.Quantity);
            if (item is null || pair.Value <= 0 || pair.Value + alreadyRequested > item.Quantity) return BadRequest("A return quantity is invalid.");
            var gross = item.UnitPrice * pair.Value;
            var refund = order.SubtotalAmount > 0 ? gross * order.TotalAmount / order.SubtotalAmount : gross;
            lines.Add(new ReturnRequestItem { OrderItemId = item.Id, Quantity = pair.Value, RefundAmount = decimal.Round(refund, 2) });
        }
        var result = new ReturnRequest { OrderId = order.Id, UserId = userId, Reason = request.Reason.Trim(), Items = lines, RefundAmount = lines.Sum(x => x.RefundAmount) };
        db.ReturnRequests.Add(result); await db.SaveChangesAsync(ct);
        return Ok(new { result.Id, result.Status, result.RefundAmount });
    }

    [HttpGet("returns/mine")]
    public async Task<ActionResult<object>> MyReturns(CancellationToken ct) => Ok(await db.ReturnRequests.AsNoTracking().Where(x => x.UserId == CurrentUserId()).OrderByDescending(x => x.CreatedAt)
        .Select(x => new { x.Id, x.OrderId, x.Reason, x.Status, x.RefundAmount, x.AdminNotes, x.CreatedAt, x.ResolvedAt }).ToListAsync(ct));

    [HttpGet("returns")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<ActionResult<object>> Returns([FromQuery] string? status, CancellationToken ct)
    {
        var query = db.ReturnRequests.AsNoTracking().AsQueryable(); if (!string.IsNullOrWhiteSpace(status)) query = query.Where(x => x.Status == status);
        return Ok(await query.OrderByDescending(x => x.CreatedAt).Take(500).Select(x => new { x.Id, x.OrderId, x.UserId, x.Reason, x.Status, x.RefundAmount, x.AdminNotes, x.CreatedAt, x.ResolvedAt }).ToListAsync(ct));
    }

    [HttpPut("returns/{id:int}/resolve")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<IActionResult> ResolveReturn(int id, ReturnResolutionRequest request, CancellationToken ct)
    {
        var item = await db.ReturnRequests.Include(x => x.Items).ThenInclude(x => x.OrderItem).ThenInclude(x => x.Product).Include(x => x.Order).ThenInclude(x => x.Payment).SingleOrDefaultAsync(x => x.Id == id, ct);
        if (item is null) return NotFound(); if (item.Status != "Requested") return Conflict("This return was already resolved.");
        if (!request.Approve)
        {
            item.Status = "Rejected"; item.AdminNotes = request.AdminNotes?.Trim(); item.ResolvedAt = DateTime.UtcNow; await db.SaveChangesAsync(ct);
            await notifications.CreateAsync(new NotificationInsertRequest { Title = "Return request declined", Message = $"Your return for order {item.Order.OrderNumber} was declined.", Type = "Orders", RecipientUserIds = [item.UserId] });
            return NoContent();
        }
        var stripeRefunded = false;
        if (item.Order.Payment is { Provider: "Stripe" } payment)
        {
            if (payment.Status is not ("Completed" or "PartiallyRefunded")) return Conflict("The Stripe payment cannot accept this refund.");
            await stripe.RefundAsync(payment.Id, new StripeRefundRequest { Amount = item.RefundAmount, Reason = "Approved merchandise return" }, ct);
            stripeRefunded = true;
        }
        await using var transaction = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable, ct);
        foreach (var line in item.Items)
        {
            line.OrderItem.Product.StockQuantity += line.Quantity; line.Restocked = true;
            db.InventoryMovements.Add(new InventoryMovement { ProductId = line.OrderItem.ProductId, QuantityChange = line.Quantity, BalanceAfter = line.OrderItem.Product.StockQuantity, Reason = "Approved return", ReferenceType = "Return", ReferenceId = item.Id, ActorUserId = CurrentUserId() });
        }
        item.Status = stripeRefunded ? "Refunded" : "Approved"; item.AdminNotes = request.AdminNotes?.Trim(); item.ResolvedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct); await transaction.CommitAsync(ct);
        await notifications.CreateAsync(new NotificationInsertRequest { Title = "Return approved", Message = $"Your return for order {item.Order.OrderNumber} was approved.", Type = "Orders", RecipientUserIds = [item.UserId] });
        return NoContent();
    }

    private int CurrentUserId() => int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : throw new UnauthorizedAccessException();
    private static string? CanonicalType(string type) => new[] { "Percentage", "Fixed" }.FirstOrDefault(x => x.Equals(type.Trim(), StringComparison.OrdinalIgnoreCase));
    private static string? ValidateCoupon(CouponRequest x)
    {
        var type = CanonicalType(x.DiscountType);
        if (x.Code.Trim().Length is < 3 or > 40 || type is null || x.Value <= 0 || x.MinimumOrderAmount < 0 || x.ValidUntil <= x.ValidFrom || x.PerUserLimit < 1 || x.UsageLimit < 1) return "Coupon configuration is invalid.";
        if (type == "Percentage" && x.Value > 100) return "Percentage discount cannot exceed 100.";
        return null;
    }
}

public sealed record InventoryAdjustmentRequest(int QuantityChange, string Reason);
public sealed record CouponRequest(string Code, string DiscountType, decimal Value, decimal MinimumOrderAmount, decimal? MaximumDiscount, DateTime ValidFrom, DateTime ValidUntil, int? UsageLimit, int PerUserLimit, bool IsActive);
public sealed record ReturnLineRequest(int OrderItemId, int Quantity);
public sealed record ReturnCreateRequest(int OrderId, string Reason, List<ReturnLineRequest> Items);
public sealed record ReturnResolutionRequest(bool Approve, string? AdminNotes);
