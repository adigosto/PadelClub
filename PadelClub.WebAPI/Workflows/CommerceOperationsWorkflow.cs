using System.Numerics;
using Microsoft.EntityFrameworkCore;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Services;
using PadelClub.Services.Database;
using PadelClub.WebAPI.Commerce;
using PadelClub.WebAPI.Payments;
using PadelClub.WebAPI.Authentication;
using static PadelClub.WebAPI.Workflows.WorkflowResults;

namespace PadelClub.WebAPI.Workflows;

public sealed class CommerceOperationsWorkflow(PadelClubContext db, IProviderRefundOperationService refundOperations, INotificationService notifications, ICurrentUser currentUser)
{

    public async Task<WorkflowResult> AdjustInventory(int productId, InventoryAdjustmentRequest request, CancellationToken ct)
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


    public async Task<WorkflowResult> InventoryHistory(int productId, CancellationToken ct) => Ok(await db.InventoryMovements.AsNoTracking().Where(x => x.ProductId == productId)
        .OrderByDescending(x => x.CreatedAt).Take(500).Select(x => new { x.Id, x.QuantityChange, x.BalanceAfter, x.Reason, x.ReferenceType, x.ReferenceId, x.ActorUserId, x.CreatedAt }).ToListAsync(ct));


    public async Task<WorkflowResult> CreateCoupon(CouponRequest request, CancellationToken ct)
    {
        var error = ValidateCoupon(request); if (error is not null) return BadRequest(error);
        var code = request.Code.Trim().ToUpperInvariant();
        if (await db.Coupons.AnyAsync(x => x.Code == code, ct)) return Conflict("Coupon code already exists.");
        var coupon = new Coupon { Code = code, DiscountType = CanonicalType(request.DiscountType)!, Value = request.Value, MinimumOrderAmount = request.MinimumOrderAmount,
            MaximumDiscount = request.MaximumDiscount, ValidFrom = request.ValidFrom, ValidUntil = request.ValidUntil, UsageLimit = request.UsageLimit, PerUserLimit = request.PerUserLimit, IsActive = request.IsActive };
        db.Coupons.Add(coupon); await db.SaveChangesAsync(ct);
        return Ok(new { coupon.Id, coupon.Code });
    }


    public async Task<WorkflowResult> UpdateCoupon(int id, CouponRequest request, CancellationToken ct)
    {
        var error = ValidateCoupon(request); if (error is not null) return BadRequest(error);
        var coupon = await db.Coupons.SingleOrDefaultAsync(x => x.Id == id, ct); if (coupon is null) return NotFound();
        var code = request.Code.Trim().ToUpperInvariant();
        if (await db.Coupons.AnyAsync(x => x.Id != id && x.Code == code, ct)) return Conflict("Coupon code already exists.");
        coupon.Code = code; coupon.DiscountType = CanonicalType(request.DiscountType)!; coupon.Value = request.Value; coupon.MinimumOrderAmount = request.MinimumOrderAmount;
        coupon.MaximumDiscount = request.MaximumDiscount; coupon.ValidFrom = request.ValidFrom; coupon.ValidUntil = request.ValidUntil; coupon.UsageLimit = request.UsageLimit;
        coupon.PerUserLimit = request.PerUserLimit; coupon.IsActive = request.IsActive; await db.SaveChangesAsync(ct); return NoContent();
    }


    public async Task<WorkflowResult> Coupons(CancellationToken ct) => Ok(await db.Coupons.AsNoTracking().OrderByDescending(x => x.ValidUntil).Take(500)
        .Select(x => new { x.Id, x.Code, x.DiscountType, x.Value, x.MinimumOrderAmount, x.MaximumDiscount, x.ValidFrom, x.ValidUntil, x.UsageLimit, x.UsageCount, x.PerUserLimit, x.IsActive }).ToListAsync(ct));

    public async Task<WorkflowResult> RequestReturn(ReturnCreateRequest request, CancellationToken ct)
    {
        if (request is null)
            return BadRequest("A reason and at least one item are required.");

        var reason = request.Reason?.Trim();
        if (request.OrderId <= 0 || reason is null || reason.Length is < 5 or > 1000 || request.Items is not { Count: > 0 })
            return BadRequest("A reason and at least one item are required.");

        // Aggregate in Int64, never Int32: duplicate client lines must not be
        // able to overflow before the quantity validation below runs.
        var quantities = new Dictionary<int, long>();
        foreach (var requestedLine in request.Items)
        {
            if (requestedLine is null || requestedLine.OrderItemId <= 0 || requestedLine.Quantity <= 0)
                return BadRequest("A return quantity is invalid.");

            quantities.TryGetValue(requestedLine.OrderItemId, out var requestedQuantity);
            quantities[requestedLine.OrderItemId] = checked(requestedQuantity + (long)requestedLine.Quantity);
        }

        var userId = CurrentUserId();
        var now = DateTime.UtcNow;
        await using var transaction = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable, ct);

        // Every customer return for an order first acquires the same update
        // lock. This prevents two HTTP requests from both observing the same
        // remaining quantity before either one persists its reservation. The
        // serializable transaction keeps that lock through the recheck and
        // insert below.
        var order = await db.Orders
            .FromSqlInterpolated($"SELECT * FROM [Orders] WITH (UPDLOCK, HOLDLOCK) WHERE [Id] = {request.OrderId} AND [UserId] = {userId}")
            .Include(x => x.OrderItems)
            .Include(x => x.ReturnRequests)
                .ThenInclude(x => x.Items)
            .AsSplitQuery()
            .SingleOrDefaultAsync(ct);
        if (order is null) return NotFound();
        if (!ReturnEligibilityPolicy.IsEligible(order.Status, order.DeliveredAt, now)) return Conflict("This order is outside the return window.");

        if (!TryAllocateOrderRefundCents(order, out var orderRefundAllocationCents))
            return Conflict("This order has an invalid refund allocation.");

        long reservedRefundCents;
        try
        {
            reservedRefundCents = order.ReturnRequests
                .Where(returnRequest => returnRequest.Status != "Rejected")
                .Aggregate(0L, (total, returnRequest) =>
                {
                    if (returnRequest.RefundAmount < 0)
                        throw new InvalidOperationException("A return request has an invalid refund amount.");
                    return checked(total + ToCents(returnRequest.RefundAmount));
                });
        }
        catch (OverflowException)
        {
            return Conflict("This order has an invalid refund ledger.");
        }
        catch (InvalidOperationException)
        {
            return Conflict("This order has an invalid refund ledger.");
        }

        var lines = new List<ReturnRequestItem>();
        long requestedRefundCents = 0;
        foreach (var pair in quantities)
        {
            var item = order.OrderItems.SingleOrDefault(x => x.Id == pair.Key);
            if (item is null || item.Quantity <= 0)
                return BadRequest("A return quantity is invalid.");

            long alreadyRequested;
            try
            {
                alreadyRequested = order.ReturnRequests
                    .Where(returnRequest => returnRequest.Status != "Rejected")
                    .SelectMany(returnRequest => returnRequest.Items)
                    .Where(returnItem => returnItem.OrderItemId == pair.Key)
                    .Aggregate(0L, (total, returnItem) => checked(total + (long)returnItem.Quantity));
            }
            catch (OverflowException)
            {
                return Conflict("This order has an invalid return ledger.");
            }

            if (alreadyRequested < 0 || pair.Value > (long)item.Quantity - alreadyRequested)
                return BadRequest("A return quantity is invalid.");

            if (!orderRefundAllocationCents.TryGetValue(item.Id, out var lineRefundBudgetCents))
                return Conflict("This order has an invalid refund allocation.");

            var lineRefundCents = RefundCentsForReservedUnits(
                lineRefundBudgetCents,
                item.Quantity,
                alreadyRequested,
                pair.Value);
            requestedRefundCents = checked(requestedRefundCents + lineRefundCents);
            lines.Add(new ReturnRequestItem
            {
                OrderItemId = item.Id,
                Quantity = checked((int)pair.Value),
                RefundAmount = FromCents(lineRefundCents)
            });
        }

        var orderRefundBudgetCents = ToCents(order.TotalAmount);
        if (reservedRefundCents < 0 || reservedRefundCents > orderRefundBudgetCents || requestedRefundCents > orderRefundBudgetCents - reservedRefundCents)
            return Conflict("This return would exceed the order's refundable amount.");

        var result = new ReturnRequest
        {
            OrderId = order.Id,
            UserId = userId,
            Reason = reason,
            Items = lines,
            RefundAmount = FromCents(requestedRefundCents)
        };
        db.ReturnRequests.Add(result);
        await db.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
        return Ok(new { result.Id, result.Status, result.RefundAmount });
    }

    public async Task<WorkflowResult> EligibleReturnOrders(CancellationToken ct)
    {
        var userId = CurrentUserId();
        var now = DateTime.UtcNow;
        var earliestEligibleDeliveredAt = ReturnEligibilityPolicy.EarliestEligibleDeliveredAt(now);

        // The ownership and delivery/window predicates execute in SQL before
        // related lines are loaded. We then compute residual quantities in
        // memory from the already loaded, caller-owned order graph to keep the
        // non-rejected return rule identical to POST /Commerce/returns.
        var orders = await db.Orders
            .AsNoTracking()
            .Where(order =>
                order.UserId == userId &&
                order.Status == "Delivered" &&
                order.DeliveredAt != null &&
                order.DeliveredAt >= earliestEligibleDeliveredAt &&
                order.DeliveredAt <= now)
            .Include(order => order.OrderItems)
                .ThenInclude(item => item.Product)
            .Include(order => order.ReturnRequests)
                .ThenInclude(returnRequest => returnRequest.Items)
            .AsSplitQuery()
            .OrderByDescending(order => order.DeliveredAt)
            .ToListAsync(ct);

        var response = new List<EligibleReturnOrderResponse>();
        foreach (var order in orders)
        {
            // Keep the in-memory policy guard as well: it protects the exact
            // deadline semantics if the query ever changes independently.
            if (!ReturnEligibilityPolicy.IsEligible(order.Status, order.DeliveredAt, now))
                continue;

            var items = order.OrderItems
                .Select(item =>
                {
                    long alreadyRequested;
                    try
                    {
                        alreadyRequested = order.ReturnRequests
                            .Where(returnRequest => returnRequest.Status != "Rejected")
                            .SelectMany(returnRequest => returnRequest.Items)
                            .Where(returnItem => returnItem.OrderItemId == item.Id)
                            .Aggregate(0L, (total, returnItem) => checked(total + (long)returnItem.Quantity));
                    }
                    catch (OverflowException)
                    {
                        // A corrupted historical ledger must never make an
                        // order line look returnable in the customer UI.
                        alreadyRequested = item.Quantity;
                    }

                    var remaining = Math.Max(0L, (long)item.Quantity - alreadyRequested);

                    return new EligibleReturnOrderItemResponse
                    {
                        OrderItemId = item.Id,
                        ProductName = item.Product.Name,
                        Quantity = item.Quantity,
                        RemainingReturnableQuantity = checked((int)remaining),
                        UnitPrice = item.UnitPrice,
                        LineTotal = item.TotalPrice
                    };
                })
                .Where(item => item.RemainingReturnableQuantity > 0)
                .OrderBy(item => item.OrderItemId)
                .ToList();

            if (items.Count == 0)
                continue;

            response.Add(new EligibleReturnOrderResponse
            {
                OrderId = order.Id,
                OrderNumber = order.OrderNumber,
                DeliveredAt = order.DeliveredAt!.Value,
                ReturnWindowEndsAt = ReturnEligibilityPolicy.ReturnWindowEndsAt(order.DeliveredAt.Value),
                Items = items
            });
        }

        return Ok(response);
    }

    public async Task<WorkflowResult> MyReturns(CancellationToken ct) => Ok(await db.ReturnRequests.AsNoTracking().Where(x => x.UserId == CurrentUserId()).OrderByDescending(x => x.CreatedAt)
        .Select(x => new { x.Id, x.OrderId, x.Reason, x.Status, x.RefundAmount, x.AdminNotes, x.CreatedAt, x.ResolvedAt }).ToListAsync(ct));


    public async Task<WorkflowResult> Returns(string? status, CancellationToken ct)
    {
        var query = db.ReturnRequests.AsNoTracking().AsQueryable(); if (!string.IsNullOrWhiteSpace(status)) query = query.Where(x => x.Status == status);
        return Ok(await query.OrderByDescending(x => x.CreatedAt).Take(500).Select(x => new { x.Id, x.OrderId, x.UserId, x.Reason, x.Status, x.RefundAmount, x.AdminNotes, x.CreatedAt, x.ResolvedAt }).ToListAsync(ct));
    }


    public async Task<WorkflowResult> ResolveReturn(int id, ReturnResolutionRequest request, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable, ct);

        // This is the resolution claim. SQL Server takes and retains an update
        // lock on the exact return row until the serializable transaction ends.
        // A second administrator resolving the same return therefore waits,
        // re-reads the committed status, and receives the existing conflict
        // instead of issuing a second refund or restocking the items twice.
        // The non-SQL-Server branch keeps local/test-provider compatibility;
        // production and the relational integration tests use the SQL Server
        // key lock above.
        IQueryable<ReturnRequest> returnRequests = db.Database.IsSqlServer()
            ? db.ReturnRequests.FromSqlInterpolated($"SELECT * FROM [ReturnRequests] WITH (UPDLOCK, HOLDLOCK) WHERE [Id] = {id}")
            : db.ReturnRequests.Where(x => x.Id == id);
        var item = await returnRequests
            .Include(x => x.Items)
                .ThenInclude(x => x.OrderItem)
                    .ThenInclude(x => x.Product)
            .Include(x => x.Order)
                .ThenInclude(x => x.Payment)
            .AsSplitQuery()
            .SingleOrDefaultAsync(ct);
        if (item is null) return NotFound();
        if (item.Status != "Requested") return Conflict("This return was already resolved.");
        if (!request.Approve)
        {
            item.Status = "Rejected"; item.AdminNotes = request.AdminNotes?.Trim(); item.ResolvedAt = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
            await notifications.CreateAsync(new NotificationInsertRequest { Title = "Return request declined", Message = $"Your return for order {item.Order.OrderNumber} was declined.", Type = "Orders", RecipientUserIds = [item.UserId] });
            return NoContent();
        }
        if (item.Order.Payment is { Provider: "Stripe" } payment)
        {
            if (payment.Status is not ("Completed" or "PartiallyRefunded")) return Conflict("The Stripe payment cannot accept this refund.");

            // Commit an immutable intent before contacting Stripe. The worker
            // will reconcile its metadata/idempotency key after any process or
            // SQL failure, then restock only after the provider refund has
            // been accepted and settled locally.
            var operation = await refundOperations.QueueReturnWithinTransactionAsync(
                item,
                payment,
                CurrentUserId(),
                "Approved merchandise return",
                ct);
            item.Status = "RefundPending";
            item.AdminNotes = request.AdminNotes?.Trim();
            await db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
            return Accepted(new
            {
                item.Id,
                item.Status,
                RefundOperationId = operation.Id,
                operation.Amount,
                operation.Currency
            });
        }
        foreach (var line in item.Items)
        {
            line.OrderItem.Product.StockQuantity += line.Quantity; line.Restocked = true;
            db.InventoryMovements.Add(new InventoryMovement { ProductId = line.OrderItem.ProductId, QuantityChange = line.Quantity, BalanceAfter = line.OrderItem.Product.StockQuantity, Reason = "Approved return", ReferenceType = "Return", ReferenceId = item.Id, ActorUserId = CurrentUserId() });
        }
        item.Status = "Approved"; item.AdminNotes = request.AdminNotes?.Trim(); item.ResolvedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct); await transaction.CommitAsync(ct);
        await notifications.CreateAsync(new NotificationInsertRequest { Title = "Return approved", Message = $"Your return for order {item.Order.OrderNumber} was approved.", Type = "Orders", RecipientUserIds = [item.UserId] });
        return NoContent();
    }

    private int CurrentUserId() => currentUser.Id;

    /// <summary>
    /// Allocates the order total in integer cents across order lines using the
    /// largest-remainder method. A line is then split into deterministic unit
    /// positions by <see cref="RefundCentsForReservedUnits"/>. Consequently,
    /// a sequence of partial requests can never round up beyond the original
    /// order total.
    /// </summary>
    private static bool TryAllocateOrderRefundCents(Order order, out Dictionary<int, long> allocation)
    {
        allocation = new Dictionary<int, long>();
        if (order.TotalAmount < 0 || order.OrderItems.Count == 0)
            return false;

        var lines = new List<(int OrderItemId, int Quantity, long WeightCents)>();
        foreach (var item in order.OrderItems)
        {
            if (item.Id <= 0 || item.Quantity <= 0 || item.TotalPrice < 0)
                return false;

            lines.Add((item.Id, item.Quantity, ToCents(item.TotalPrice)));
        }

        var refundBudgetCents = ToCents(order.TotalAmount);
        if (refundBudgetCents == 0)
        {
            foreach (var line in lines)
                allocation[line.OrderItemId] = 0;
            return true;
        }

        var totalWeight = lines.Aggregate(BigInteger.Zero, (total, line) => total + line.WeightCents);
        if (totalWeight <= 0)
            return false;

        var remainders = new List<(int OrderItemId, BigInteger Remainder)>();
        long allocatedCents = 0;
        foreach (var line in lines)
        {
            var numerator = (BigInteger)refundBudgetCents * line.WeightCents;
            var cents = (long)(numerator / totalWeight);
            allocation[line.OrderItemId] = cents;
            allocatedCents = checked(allocatedCents + cents);
            remainders.Add((line.OrderItemId, numerator % totalWeight));
        }

        var undistributedCents = refundBudgetCents - allocatedCents;
        foreach (var remainder in remainders
                     .OrderByDescending(line => line.Remainder)
                     .ThenBy(line => line.OrderItemId)
                     .Take(checked((int)undistributedCents)))
        {
            allocation[remainder.OrderItemId]++;
        }

        return true;
    }

    private static long RefundCentsForReservedUnits(long lineRefundBudgetCents, int itemQuantity, long reservedQuantity, long requestedQuantity)
    {
        var quantity = (long)itemQuantity;
        if (lineRefundBudgetCents < 0 || itemQuantity <= 0 || reservedQuantity < 0 || requestedQuantity <= 0 || reservedQuantity + requestedQuantity > quantity)
            throw new InvalidOperationException("A return quantity is invalid.");

        var centsPerUnit = lineRefundBudgetCents / quantity;
        var extraCentUnits = lineRefundBudgetCents % quantity;
        var requestEndsAt = reservedQuantity + requestedQuantity;
        var extraCentsInRequest = Math.Max(
            0L,
            Math.Min(requestEndsAt, extraCentUnits) - Math.Min(reservedQuantity, extraCentUnits));
        return checked(centsPerUnit * requestedQuantity + extraCentsInRequest);
    }

    private static long ToCents(decimal amount) =>
        decimal.ToInt64(decimal.Round(amount * 100m, 0, MidpointRounding.AwayFromZero));

    private static decimal FromCents(long cents) => cents / 100m;

    private static string? CanonicalType(string type) => new[] { "Percentage", "Fixed" }.FirstOrDefault(x => x.Equals(type.Trim(), StringComparison.OrdinalIgnoreCase));
    private static string? ValidateCoupon(CouponRequest x)
    {
        var type = CanonicalType(x.DiscountType);
        if (x.Code.Trim().Length is < 3 or > 40 || type is null || x.Value <= 0 || x.MinimumOrderAmount < 0 || x.ValidUntil <= x.ValidFrom || x.PerUserLimit < 1 || x.UsageLimit < 1) return "Coupon configuration is invalid.";
        if (type == "Percentage" && x.Value > 100) return "Percentage discount cannot exceed 100.";
        return null;
    }

}
