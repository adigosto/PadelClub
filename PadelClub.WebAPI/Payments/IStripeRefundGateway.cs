using PadelClub.Services.Database;

namespace PadelClub.WebAPI.Payments;

/// <summary>
/// Isolates external Stripe I/O from durable SQL state transitions. It must
/// return an already-created provider refund when a prior attempt succeeded
/// but the application crashed before it could record the result locally.
/// </summary>
public interface IStripeRefundGateway
{
    Task<StripeRefundGatewayResult> CreateOrReconcileAsync(
        ProviderRefundOperation operation,
        CancellationToken cancellationToken);
}

public sealed record StripeRefundGatewayResult(
    string ProviderRefundId,
    decimal Amount,
    DateTime ProviderAcceptedAtUtc);
