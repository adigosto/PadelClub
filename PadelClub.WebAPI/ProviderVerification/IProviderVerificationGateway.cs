namespace PadelClub.WebAPI.ProviderVerification;

/// <summary>
/// Narrow external boundary for deliberately authorised rehearsal calls.
/// Implementations must not log secret material or target identifiers.
/// </summary>
public interface IProviderVerificationGateway
{
    Task VerifyStripeTestReadAsync(string paymentIntentId, CancellationToken cancellationToken);

    Task VerifySmtpAsync(string recipient, Guid correlationId, CancellationToken cancellationToken);

    Task VerifyFirebaseAsync(string installationId, Guid correlationId, CancellationToken cancellationToken);
}

/// <summary>Safe, intentionally generic condition exposed to administrators.</summary>
public sealed class ProviderVerificationPreconditionException(string message) : InvalidOperationException(message);

/// <summary>
/// Indicates a provider rejected a bounded rehearsal after an outbound call.
/// The exception message must stay generic because raw provider details are
/// never persisted or returned.
/// </summary>
public sealed class ProviderVerificationRejectedException(string message) : Exception(message);
