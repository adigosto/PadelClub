namespace PadelClub.WebAPI.Payments;

/// <summary>
/// Status values persisted on a provider refund operation. Pending remains
/// deliberately retryable until the provider result has been reconciled into
/// the local payment and, for merchandise returns, local stock.
/// </summary>
public static class ProviderRefundOperationStatuses
{
    public const string Pending = "Pending";
    public const string Succeeded = "Succeeded";
}
