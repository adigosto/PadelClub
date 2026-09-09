using Microsoft.Extensions.Options;
using PadelClub.Services.Database;
using Stripe;

namespace PadelClub.WebAPI.Payments;

/// <summary>
/// Stripe-only gateway. It reconciles provider metadata before issuing a
/// create request, then uses the immutable SQL idempotency key for the create
/// itself. This covers the important failure window where Stripe accepted a
/// refund but the process died before SQL settlement.
/// </summary>
public sealed class StripeRefundGateway(IOptions<StripeOptions> options) : IStripeRefundGateway
{
    private readonly StripeOptions _options = options.Value;

    public async Task<StripeRefundGatewayResult> CreateOrReconcileAsync(
        ProviderRefundOperation operation,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(operation);
        EnsureConfigured();
        if (!operation.Provider.Equals("Stripe", StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException($"Unsupported refund provider '{operation.Provider}'.");
        if (string.IsNullOrWhiteSpace(operation.PaymentIntentId))
            throw new InvalidOperationException("The durable refund operation has no Stripe payment-intent identifier.");

        var service = new RefundService(new StripeClient(_options.SecretKey));
        var knownRefund = await FindByOperationMetadataAsync(service, operation, cancellationToken);
        if (knownRefund is not null)
            return ToResult(knownRefund, operation);

        var refund = await service.CreateAsync(
            new RefundCreateOptions
            {
                PaymentIntent = operation.PaymentIntentId,
                Amount = ToMinorUnits(operation.Amount),
                Reason = "requested_by_customer",
                Metadata = new Dictionary<string, string>
                {
                    ["provider_refund_operation_id"] = operation.Id.ToString("D"),
                    ["payment_id"] = operation.PaymentId.ToString(),
                    ["return_request_id"] = operation.ReturnRequestId?.ToString() ?? string.Empty,
                    ["internal_reason"] = operation.Reason
                }
            },
            new RequestOptions { IdempotencyKey = operation.IdempotencyKey },
            cancellationToken);
        return ToResult(refund, operation);
    }

    private static async Task<Refund?> FindByOperationMetadataAsync(
        RefundService service,
        ProviderRefundOperation operation,
        CancellationToken cancellationToken)
    {
        // Stripe's list call lets us settle a result that was accepted before
        // a lost HTTP response or a process/database failure. The subsequent
        // immutable idempotency key remains the final protection if this list
        // response is incomplete or a retry races with a prior create call.
        var refunds = await service.ListAsync(
            new RefundListOptions { PaymentIntent = operation.PaymentIntentId, Limit = 100 },
            cancellationToken: cancellationToken);
        return refunds.Data.SingleOrDefault(refund =>
            refund.Metadata is not null &&
            refund.Metadata.TryGetValue("provider_refund_operation_id", out var operationId) &&
            operationId.Equals(operation.Id.ToString("D"), StringComparison.OrdinalIgnoreCase));
    }

    private static StripeRefundGatewayResult ToResult(Refund refund, ProviderRefundOperation operation)
    {
        if (string.IsNullOrWhiteSpace(refund.Id))
            throw new InvalidOperationException("Stripe returned a refund without an identifier.");
        var amount = refund.Amount / 100m;
        if (amount != operation.Amount)
            throw new InvalidOperationException("Stripe returned a refund amount that differs from the durable refund operation.");
        return new StripeRefundGatewayResult(refund.Id, amount, DateTime.UtcNow);
    }

    private static long ToMinorUnits(decimal amount)
    {
        var rounded = decimal.Round(amount * 100m, 0, MidpointRounding.AwayFromZero);
        if (rounded <= 0 || rounded > long.MaxValue)
            throw new InvalidOperationException("The refund amount is invalid for Stripe.");
        return checked((long)rounded);
    }

    private void EnsureConfigured()
    {
        if (string.IsNullOrWhiteSpace(_options.SecretKey))
            throw new InvalidOperationException("Stripe is not configured. Set Stripe__SecretKey before queued refunds can be submitted.");
    }
}
