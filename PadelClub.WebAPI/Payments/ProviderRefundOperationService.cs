using Microsoft.EntityFrameworkCore;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Services.Database;

namespace PadelClub.WebAPI.Payments;

/// <summary>
/// Creates durable refund intents before any call to Stripe. The operation
/// record, rather than an in-memory HTTP request, is the source of truth for
/// retries and post-crash reconciliation.
/// </summary>
public sealed class ProviderRefundOperationService(PadelClubContext database) : IProviderRefundOperationService
{
    public async Task<ProviderRefundOperation> QueueReturnWithinTransactionAsync(
        ReturnRequest returnRequest,
        Payment payment,
        int requestedByUserId,
        string reason,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(returnRequest);
        ArgumentNullException.ThrowIfNull(payment);
        EnsureEligibleStripePayment(payment);

        await EnsureReservationCreditNotIssuedAsync(payment, cancellationToken);

        if (returnRequest.Id <= 0)
            throw new InvalidOperationException("The return request must be saved before its refund can be queued.");
        if (returnRequest.RefundAmount <= 0)
            throw new InvalidOperationException("The return refund amount must be positive.");

        var idempotencyKey = $"return-refund-v1:{returnRequest.Id}";
        var existing = await database.ProviderRefundOperations
            .SingleOrDefaultAsync(operation => operation.IdempotencyKey == idempotencyKey, cancellationToken);
        if (existing is not null)
        {
            if (existing.PaymentId != payment.Id || existing.ReturnRequestId != returnRequest.Id)
                throw new InvalidOperationException("The durable return-refund operation does not match this return.");
            return existing;
        }

        var expectedRefundedAmount = await EnsureRefundCapacityAsync(payment, returnRequest.RefundAmount, cancellationToken);
        var operation = CreateOperation(
            payment,
            returnRequest.Id,
            requestedByUserId,
            returnRequest.RefundAmount,
            expectedRefundedAmount,
            NormalizeReason(reason),
            idempotencyKey);
        database.ProviderRefundOperations.Add(operation);
        return operation;
    }

    public async Task<ProviderRefundOperation> QueueDirectAsync(
        int paymentId,
        int requestedByUserId,
        StripeRefundRequest request,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(request);
        var suppliedKey = request.IdempotencyKey?.Trim();
        if (suppliedKey is null || suppliedKey.Length is < 8 or > 100)
            throw new InvalidOperationException("A stable refund idempotency key between 8 and 100 characters is required.");

        var idempotencyKey = $"manual-refund-v1:{paymentId}:{suppliedKey}";
        await using var transaction = database.Database.IsRelational()
            ? await database.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable, cancellationToken)
            : null;

        var existing = await database.ProviderRefundOperations
            .SingleOrDefaultAsync(operation => operation.IdempotencyKey == idempotencyKey, cancellationToken);
        if (existing is not null)
        {
            if (existing.PaymentId != paymentId)
                throw new InvalidOperationException("The idempotency key is already associated with another payment.");
            if (transaction is not null) await transaction.CommitAsync(cancellationToken);
            return existing;
        }

        IQueryable<Payment> payments = database.Database.IsSqlServer()
            ? database.Payments.FromSqlInterpolated($"SELECT * FROM [Payments] WITH (UPDLOCK, HOLDLOCK) WHERE [Id] = {paymentId}")
            : database.Payments.Where(payment => payment.Id == paymentId);
        var payment = await payments.SingleOrDefaultAsync(cancellationToken)
            ?? throw new InvalidOperationException("Stripe payment was not found.");
        EnsureEligibleStripePayment(payment);
        await EnsureReservationCreditNotIssuedAsync(payment, cancellationToken);

        var pendingTotal = await PendingRefundTotalAsync(payment.Id, cancellationToken);
        var amount = request.Amount ?? payment.Amount - payment.RefundedAmount - pendingTotal;
        if (amount <= 0)
            throw new InvalidOperationException("There is no refundable Stripe payment balance remaining.");
        var expectedRefundedAmount = EnsureRefundCapacity(payment, amount, pendingTotal);

        var operation = CreateOperation(
            payment,
            null,
            requestedByUserId,
            amount,
            expectedRefundedAmount,
            NormalizeReason(request.Reason),
            idempotencyKey);
        database.ProviderRefundOperations.Add(operation);
        await database.SaveChangesAsync(cancellationToken);
        if (transaction is not null) await transaction.CommitAsync(cancellationToken);
        return operation;
    }

    public Task<ProviderRefundOperationResponse?> GetAsync(Guid operationId, CancellationToken cancellationToken) =>
        database.ProviderRefundOperations.AsNoTracking()
            .Where(operation => operation.Id == operationId)
            .Select(operation => new ProviderRefundOperationResponse
            {
                Id = operation.Id,
                PaymentId = operation.PaymentId,
                ReturnRequestId = operation.ReturnRequestId,
                Amount = operation.Amount,
                Currency = operation.Currency,
                Provider = operation.Provider,
                Status = operation.Status,
                ProviderRefundId = operation.ProviderRefundId,
                AttemptCount = operation.AttemptCount,
                NextAttemptAtUtc = operation.NextAttemptAtUtc,
                LastError = operation.LastError,
                CreatedAtUtc = operation.CreatedAtUtc,
                ProviderAcceptedAtUtc = operation.ProviderAcceptedAtUtc,
                CompletedAtUtc = operation.CompletedAtUtc
            })
            .SingleOrDefaultAsync(cancellationToken);

    private async Task<decimal> EnsureRefundCapacityAsync(Payment payment, decimal requestedAmount, CancellationToken cancellationToken)
    {
        var pendingTotal = await PendingRefundTotalAsync(payment.Id, cancellationToken);
        return EnsureRefundCapacity(payment, requestedAmount, pendingTotal);
    }

    private async Task EnsureReservationCreditNotIssuedAsync(Payment payment, CancellationToken cancellationToken)
    {
        if (payment.ReservationId.HasValue && await database.AccountCredits.AnyAsync(
                credit => credit.ReservationId == payment.ReservationId.Value,
                cancellationToken))
            throw new InvalidOperationException("This reservation was already compensated with account credit.");
    }

    private static decimal EnsureRefundCapacity(Payment payment, decimal requestedAmount, decimal pendingTotal)
    {
        if (requestedAmount <= 0 || decimal.Round(requestedAmount, 2) != requestedAmount)
            throw new InvalidOperationException("The refund amount must be a positive value with at most two decimal places.");

        // Pending durable operations reserve balance too. Otherwise two
        // separate admins could queue individually valid partial refunds that
        // together exceed the original payment while Stripe is unavailable.
        if (requestedAmount > payment.Amount - payment.RefundedAmount - pendingTotal)
            throw new InvalidOperationException("The requested refund exceeds the remaining payment balance after pending refunds.");
        return payment.RefundedAmount + pendingTotal + requestedAmount;
    }

    private async Task<decimal> PendingRefundTotalAsync(int paymentId, CancellationToken cancellationToken) =>
        await database.ProviderRefundOperations
            .Where(operation => operation.PaymentId == paymentId && operation.Status == ProviderRefundOperationStatuses.Pending)
            .Select(operation => (decimal?)operation.Amount)
            .SumAsync(cancellationToken) ?? 0m;

    private static ProviderRefundOperation CreateOperation(
        Payment payment,
        int? returnRequestId,
        int requestedByUserId,
        decimal amount,
        decimal expectedRefundedAmount,
        string reason,
        string idempotencyKey) => new()
    {
        PaymentId = payment.Id,
        ReturnRequestId = returnRequestId,
        RequestedByUserId = requestedByUserId,
        Provider = "Stripe",
        Currency = payment.Currency.ToLowerInvariant(),
        PaymentIntentId = payment.TransactionId!,
        Amount = amount,
        ExpectedRefundedAmount = expectedRefundedAmount,
        Reason = reason,
        IdempotencyKey = idempotencyKey,
        Status = ProviderRefundOperationStatuses.Pending,
        NextAttemptAtUtc = DateTime.UtcNow,
        CreatedAtUtc = DateTime.UtcNow
    };

    private static void EnsureEligibleStripePayment(Payment payment)
    {
        if (!payment.Provider.Equals("Stripe", StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Stripe payment was not found.");
        if (payment.Status is not ("Completed" or "PartiallyRefunded"))
            throw new InvalidOperationException("Only completed Stripe payments can be refunded.");
        if (string.IsNullOrWhiteSpace(payment.TransactionId))
            throw new InvalidOperationException("The Stripe payment intent identifier is missing.");
        if (string.IsNullOrWhiteSpace(payment.Currency) || payment.Currency.Trim().Length != 3)
            throw new InvalidOperationException("The Stripe payment has an invalid currency.");
    }

    private static string NormalizeReason(string? reason)
    {
        var normalized = reason?.Trim();
        if (string.IsNullOrWhiteSpace(normalized))
            return "requested_by_customer";
        if (normalized.Length > 1000)
            throw new InvalidOperationException("The refund reason must be at most 1000 characters.");
        return normalized;
    }
}
