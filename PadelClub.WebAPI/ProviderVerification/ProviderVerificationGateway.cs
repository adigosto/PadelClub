using Microsoft.Extensions.Options;
using PadelClub.WebAPI.Notifications;
using PadelClub.WebAPI.Payments;
using Stripe;

namespace PadelClub.WebAPI.ProviderVerification;

/// <summary>
/// Performs the smallest bounded action that can demonstrate a real provider
/// result. Stripe is deliberately read-only and test-mode-only; SMTP and FCM
/// use fixed configuration targets and a correlation-only message.
/// </summary>
public sealed class ProviderVerificationGateway(
    IOptions<StripeOptions> stripeOptions,
    IServiceProvider services) : IProviderVerificationGateway
{
    private readonly StripeOptions _stripeOptions = stripeOptions.Value;

    public async Task VerifyStripeTestReadAsync(string paymentIntentId, CancellationToken cancellationToken)
    {
        var secret = _stripeOptions.SecretKey?.Trim() ?? string.Empty;
        if (!secret.StartsWith("sk_test_", StringComparison.Ordinal))
            throw new ProviderVerificationPreconditionException(
                "Stripe verification requires a configured test-mode secret key.");

        var intent = await new PaymentIntentService(new StripeClient(secret))
            .GetAsync(paymentIntentId, cancellationToken: cancellationToken);
        if (intent.Livemode)
            throw new ProviderVerificationRejectedException(
                "Stripe returned a live-mode object; no live provider verification is permitted here.");
    }

    public async Task VerifySmtpAsync(string recipient, Guid correlationId, CancellationToken cancellationToken)
    {
        var messageId = await services.GetRequiredService<IEmailSender>().SendAsync(
            recipient,
            "PadelClub SMTP verification",
            $"PadelClub provider verification correlation: {correlationId:D}",
            cancellationToken);
        if (string.IsNullOrWhiteSpace(messageId))
            throw new ProviderVerificationRejectedException("SMTP did not return an acceptance identifier.");
    }

    public async Task VerifyFirebaseAsync(string installationId, Guid correlationId, CancellationToken cancellationToken)
    {
        var messageId = await services.GetRequiredService<IPushSender>().SendAsync(
            installationId,
            "PadelClub verification",
            "A provider verification was requested by an administrator.",
            new Dictionary<string, string>
            {
                ["kind"] = "provider-verification",
                ["correlationId"] = correlationId.ToString("D")
            },
            cancellationToken);
        if (string.IsNullOrWhiteSpace(messageId))
            throw new ProviderVerificationRejectedException("Firebase did not return an acceptance identifier.");
    }
}
