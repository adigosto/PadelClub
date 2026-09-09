using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Services.Database;

namespace PadelClub.WebAPI.Payments;

public interface IProviderRefundOperationService
{
    /// <summary>
    /// Adds a Stripe-return operation to the caller's already-open
    /// serializable transaction. It deliberately performs no provider I/O.
    /// </summary>
    Task<ProviderRefundOperation> QueueReturnWithinTransactionAsync(
        ReturnRequest returnRequest,
        Payment payment,
        int requestedByUserId,
        string reason,
        CancellationToken cancellationToken);

    /// <summary>
    /// Queues an administrator's standalone Stripe refund and returns the
    /// original operation when the idempotency key is retried.
    /// </summary>
    Task<ProviderRefundOperation> QueueDirectAsync(
        int paymentId,
        int requestedByUserId,
        StripeRefundRequest request,
        CancellationToken cancellationToken);

    Task<ProviderRefundOperationResponse?> GetAsync(Guid operationId, CancellationToken cancellationToken);
}
