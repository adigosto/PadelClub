using PadelClub.Model.Requests;
using PadelClub.Model.Responses;

namespace PadelClub.WebAPI.ProviderVerification;

public interface IProviderVerificationService
{
    Task<ProviderVerificationAttemptResponse> VerifyAsync(
        int requestedByUserId,
        string provider,
        ProviderVerificationRequest request,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<ProviderVerificationAttemptResponse>> GetRecentAsync(
        CancellationToken cancellationToken = default);
}
