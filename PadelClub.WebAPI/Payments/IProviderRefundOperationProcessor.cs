using PadelClub.Services.Database;

namespace PadelClub.WebAPI.Payments;

public interface IProviderRefundOperationProcessor
{
    Task<ProviderRefundProcessResult> ProcessAsync(
        ProviderRefundOperation operation,
        Guid leaseId,
        CancellationToken cancellationToken);
}

public sealed record ProviderRefundProcessResult(bool Settled, bool AlreadySettled);
