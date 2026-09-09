using Microsoft.EntityFrameworkCore;
using PadelClub.Model.Requests;
using PadelClub.Services;
using PadelClub.Services.Database;

namespace PadelClub.WebAPI.Payments;

/// <summary>
/// Runs the two distinct halves of a refund safely: Stripe I/O occurs outside
/// SQL, then an owner-checked transaction reconciles the accepted provider
/// result into the payment, return, and inventory records. A crash between
/// those halves is recoverable because the same operation is re-reconciled.
/// </summary>
public sealed class ProviderRefundOperationProcessor(
    PadelClubContext database,
    IStripeRefundGateway gateway,
    INotificationService? notifications,
    ILogger<ProviderRefundOperationProcessor> logger) : IProviderRefundOperationProcessor
{
    public async Task<ProviderRefundProcessResult> ProcessAsync(
        ProviderRefundOperation operation,
        Guid leaseId,
        CancellationToken cancellationToken)
    {
        try
        {
            var providerResult = await gateway.CreateOrReconcileAsync(operation, cancellationToken);
            var settlement = await SettleAsync(operation.Id, leaseId, providerResult, cancellationToken);
            if (settlement.Notification is not null && notifications is not null)
                await NotifyRefundedReturnAsync(settlement.Notification, cancellationToken);
            return settlement.Result;
        }
        catch
        {
            // A failed SQL transaction leaves tracked entities in memory even
            // though its database changes were rolled back. The worker records
            // a retry through the same scoped context, so clear that stale
            // state before it can process another operation in the batch.
            database.ChangeTracker.Clear();
            throw;
        }
    }

    private async Task<Settlement> SettleAsync(
        Guid operationId,
        Guid leaseId,
        StripeRefundGatewayResult providerResult,
        CancellationToken cancellationToken)
    {
        await using var transaction = database.Database.IsRelational()
            ? await database.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable, cancellationToken)
            : null;

        IQueryable<ProviderRefundOperation> operations = database.Database.IsSqlServer()
            ? database.ProviderRefundOperations.FromSqlInterpolated($"SELECT * FROM [ProviderRefundOperations] WITH (UPDLOCK, HOLDLOCK) WHERE [Id] = {operationId}")
            : database.ProviderRefundOperations.Where(operation => operation.Id == operationId);
        var operation = await operations
            .Include(candidate => candidate.Payment)
            .Include(candidate => candidate.ReturnRequest)
                .ThenInclude(returnRequest => returnRequest!.Items)
                    .ThenInclude(item => item.OrderItem)
                        .ThenInclude(orderItem => orderItem.Product)
            .Include(candidate => candidate.ReturnRequest)
                .ThenInclude(returnRequest => returnRequest!.Order)
            .AsSplitQuery()
            .SingleOrDefaultAsync(cancellationToken);
        if (operation is null)
            throw new InvalidOperationException("The durable refund operation no longer exists.");
        if (operation.Status == ProviderRefundOperationStatuses.Succeeded)
        {
            if (transaction is not null) await transaction.CommitAsync(cancellationToken);
            return new Settlement(new ProviderRefundProcessResult(Settled: false, AlreadySettled: true), null);
        }
        if (operation.Status != ProviderRefundOperationStatuses.Pending)
            throw new InvalidOperationException($"Refund operation {operation.Id} has unsupported status '{operation.Status}'.");
        if (operation.LeaseId != leaseId || operation.LeaseExpiresAtUtc is null || operation.LeaseExpiresAtUtc <= DateTime.UtcNow)
            throw new InvalidOperationException("The refund-operation worker lease was lost before SQL settlement.");
        if (!operation.Provider.Equals("Stripe", StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException($"Unsupported refund provider '{operation.Provider}'.");
        if (providerResult.Amount != operation.Amount)
            throw new InvalidOperationException("The provider refund amount differs from the durable operation.");
        if (operation.ExpectedRefundedAmount > operation.Payment.Amount)
            throw new InvalidOperationException("The durable operation would refund more than the original payment.");

        // A Stripe charge webhook may already have observed the same provider
        // refund. ExpectedRefundedAmount was fixed at queue time, so taking
        // the maximum reconciles either ordering without counting it twice.
        operation.Payment.RefundedAmount = Math.Max(
            operation.Payment.RefundedAmount,
            operation.ExpectedRefundedAmount);
        operation.Payment.Status = operation.Payment.RefundedAmount >= operation.Payment.Amount
            ? "Refunded"
            : "PartiallyRefunded";
        operation.Payment.ReconciledAt = DateTime.UtcNow;

        ReturnRefundNotification? notification = null;
        if (operation.ReturnRequest is not null)
        {
            if (operation.ReturnRequest.Status != "RefundPending")
                throw new InvalidOperationException("The return is no longer awaiting its durable Stripe refund.");

            foreach (var line in operation.ReturnRequest.Items)
            {
                if (line.Restocked) continue;
                line.OrderItem.Product.StockQuantity += line.Quantity;
                line.Restocked = true;
                database.InventoryMovements.Add(new InventoryMovement
                {
                    ProductId = line.OrderItem.ProductId,
                    QuantityChange = line.Quantity,
                    BalanceAfter = line.OrderItem.Product.StockQuantity,
                    Reason = "Confirmed provider refund return",
                    ReferenceType = "Return",
                    ReferenceId = operation.ReturnRequest.Id,
                    ActorUserId = operation.RequestedByUserId
                });
            }

            operation.ReturnRequest.Status = "Refunded";
            operation.ReturnRequest.ResolvedAt = DateTime.UtcNow;
            notification = new ReturnRefundNotification(
                operation.ReturnRequest.UserId,
                operation.ReturnRequest.Order.OrderNumber);
        }

        operation.ProviderRefundId = providerResult.ProviderRefundId;
        operation.ProviderAcceptedAtUtc = providerResult.ProviderAcceptedAtUtc;
        operation.CompletedAtUtc = DateTime.UtcNow;
        operation.Status = ProviderRefundOperationStatuses.Succeeded;
        operation.AttemptCount++;
        operation.LastError = null;
        operation.LeaseId = null;
        operation.LeaseExpiresAtUtc = null;
        await database.SaveChangesAsync(cancellationToken);
        if (transaction is not null) await transaction.CommitAsync(cancellationToken);
        return new Settlement(new ProviderRefundProcessResult(Settled: true, AlreadySettled: false), notification);
    }

    private async Task NotifyRefundedReturnAsync(ReturnRefundNotification notification, CancellationToken cancellationToken)
    {
        var notificationService = notifications;
        if (notificationService is null) return;
        try
        {
            await notificationService.CreateAsync(new NotificationInsertRequest
            {
                Title = "Return refunded",
                Message = $"Your return for order {notification.OrderNumber} was refunded.",
                Type = "Orders",
                RecipientUserIds = [notification.UserId]
            });
        }
        catch (Exception exception) when (!cancellationToken.IsCancellationRequested)
        {
            // Payment and inventory correctness must never be rolled back just
            // because a later notification cannot be created. Delivery itself
            // is already tracked by the notification worker.
            logger.LogWarning(exception, "Refund {OrderNumber} was settled but its customer notification could not be created.", notification.OrderNumber);
        }
    }

    private sealed record Settlement(ProviderRefundProcessResult Result, ReturnRefundNotification? Notification);
    private sealed record ReturnRefundNotification(int UserId, string OrderNumber);
}
