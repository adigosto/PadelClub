using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Services.Database;
using PadelClub.WebAPI.Notifications;
using PadelClub.WebAPI.Payments;
using Stripe;

namespace PadelClub.WebAPI.ProviderVerification;

/// <summary>
/// Persists a visible <c>Started</c> row before a bounded provider rehearsal
/// and replaces it only with a normalized success/failure outcome. A stopped
/// process therefore leaves indeterminate evidence, never an invented result.
/// </summary>
public sealed class ProviderVerificationService(
    PadelClubContext db,
    IOptions<ProviderVerificationOptions> verificationOptions,
    IOptions<StripeOptions> stripeOptions,
    IOptions<NotificationDeliveryOptions> notificationOptions,
    IProviderVerificationGateway gateway) : IProviderVerificationService
{
    private readonly ProviderVerificationOptions _verificationOptions = verificationOptions.Value;
    private readonly StripeOptions _stripeOptions = stripeOptions.Value;
    private readonly NotificationDeliveryOptions _notificationOptions = notificationOptions.Value;

    public async Task<ProviderVerificationAttemptResponse> VerifyAsync(
        int requestedByUserId,
        string provider,
        ProviderVerificationRequest request,
        CancellationToken cancellationToken = default)
    {
        if (!request.ConfirmExternalCall)
            throw new ProviderVerificationPreconditionException(
                "Set confirmExternalCall to true before a provider verification can run.");

        var definition = ResolveDefinition(provider);
        var earliestAllowed = DateTime.UtcNow.AddMinutes(-_verificationOptions.MinimumIntervalMinutes);
        var hasRecentAttempt = await db.ProviderVerificationAttempts
            .AsNoTracking()
            .AnyAsync(item => item.Provider == definition.Provider && item.StartedAtUtc > earliestAllowed, cancellationToken);
        if (hasRecentAttempt)
            throw new ProviderVerificationPreconditionException(
                "A recent verification attempt already exists for this provider. Wait for the configured safety interval.");

        var attempt = new ProviderVerificationAttempt
        {
            RequestedByUserId = requestedByUserId,
            Provider = definition.Provider,
            VerificationKind = definition.VerificationKind,
            Status = ProviderVerificationAttemptStatuses.Started,
            OutcomeCategory = ProviderVerificationOutcomeCategories.Started,
            StartedAtUtc = DateTime.UtcNow
        };
        db.ProviderVerificationAttempts.Add(attempt);
        await db.SaveChangesAsync(cancellationToken);

        try
        {
            switch (definition.Provider)
            {
                case ProviderNames.Stripe:
                    await gateway.VerifyStripeTestReadAsync(
                        _verificationOptions.StripeTestPaymentIntentId.Trim(), cancellationToken);
                    attempt.OutcomeCategory = ProviderVerificationOutcomeCategories.StripeTestReadAccepted;
                    break;
                case ProviderNames.Smtp:
                    await gateway.VerifySmtpAsync(
                        _verificationOptions.SmtpRecipient.Trim(), attempt.CorrelationId, cancellationToken);
                    attempt.OutcomeCategory = ProviderVerificationOutcomeCategories.SmtpAccepted;
                    break;
                case ProviderNames.Firebase:
                    await gateway.VerifyFirebaseAsync(
                        _verificationOptions.FirebaseInstallationId.Trim(), attempt.CorrelationId, cancellationToken);
                    attempt.OutcomeCategory = ProviderVerificationOutcomeCategories.FirebaseAccepted;
                    break;
                default:
                    throw new ProviderVerificationPreconditionException("The requested provider is not supported.");
            }

            attempt.Status = ProviderVerificationAttemptStatuses.Succeeded;
        }
        catch (ProviderVerificationRejectedException)
        {
            attempt.Status = ProviderVerificationAttemptStatuses.Failed;
            attempt.OutcomeCategory = ProviderVerificationOutcomeCategories.ProviderRejected;
        }
        catch (StripeException)
        {
            attempt.Status = ProviderVerificationAttemptStatuses.Failed;
            attempt.OutcomeCategory = ProviderVerificationOutcomeCategories.ProviderRejected;
        }
        catch (HttpRequestException)
        {
            attempt.Status = ProviderVerificationAttemptStatuses.Failed;
            attempt.OutcomeCategory = ProviderVerificationOutcomeCategories.TransportFailure;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            // Preserve Started for an interrupted attempt. It is deliberately
            // not re-labelled success or failure without an observed outcome.
            throw;
        }
        catch
        {
            attempt.Status = ProviderVerificationAttemptStatuses.Failed;
            attempt.OutcomeCategory = ProviderVerificationOutcomeCategories.UnexpectedFailure;
        }

        attempt.CompletedAtUtc = DateTime.UtcNow;
        await db.SaveChangesAsync(cancellationToken);
        return ToResponse(attempt);
    }

    public async Task<IReadOnlyList<ProviderVerificationAttemptResponse>> GetRecentAsync(
        CancellationToken cancellationToken = default) => await db.ProviderVerificationAttempts
        .AsNoTracking()
        .OrderByDescending(item => item.StartedAtUtc)
        .Take(100)
        .Select(item => new ProviderVerificationAttemptResponse
        {
            CorrelationId = item.CorrelationId,
            Provider = item.Provider,
            VerificationKind = item.VerificationKind,
            Status = item.Status,
            OutcomeCategory = item.OutcomeCategory,
            StartedAtUtc = item.StartedAtUtc,
            CompletedAtUtc = item.CompletedAtUtc,
            EvidenceBoundary = BoundaryFor(item.Provider)
        })
        .ToListAsync(cancellationToken);

    private ProviderDefinition ResolveDefinition(string provider)
    {
        if (!_verificationOptions.Enabled)
            throw new ProviderVerificationPreconditionException(
                "Provider verification is disabled by server configuration.");
        if (_verificationOptions.MinimumIntervalMinutes is < 1 or > 1_440)
            throw new ProviderVerificationPreconditionException(
                "Provider verification configuration has an invalid safety interval.");

        var normalized = provider.Trim().ToLowerInvariant();
        return normalized switch
        {
            ProviderNames.Stripe => ResolveStripeDefinition(),
            ProviderNames.Smtp => ResolveSmtpDefinition(),
            ProviderNames.Firebase => ResolveFirebaseDefinition(),
            _ => throw new ArgumentException("Provider must be stripe, smtp, or firebase.", nameof(provider))
        };
    }

    private ProviderDefinition ResolveStripeDefinition()
    {
        if (!_verificationOptions.AllowStripeTestRead ||
            string.IsNullOrWhiteSpace(_verificationOptions.StripeTestPaymentIntentId))
        {
            throw new ProviderVerificationPreconditionException(
                "Stripe test-read verification is not enabled with a fixed test object.");
        }
        if (!_verificationOptions.StripeTestPaymentIntentId.Trim().StartsWith("pi_", StringComparison.Ordinal))
            throw new ProviderVerificationPreconditionException("Stripe verification has an invalid fixed test object.");
        if (!(_stripeOptions.SecretKey?.Trim() ?? string.Empty).StartsWith("sk_test_", StringComparison.Ordinal))
            throw new ProviderVerificationPreconditionException(
                "Stripe verification requires a configured test-mode secret key.");

        return new ProviderDefinition(ProviderNames.Stripe, "ReadConfiguredTestPaymentIntent");
    }

    private ProviderDefinition ResolveSmtpDefinition()
    {
        if (!_verificationOptions.AllowSmtp ||
            string.IsNullOrWhiteSpace(_verificationOptions.SmtpRecipient) ||
            string.IsNullOrWhiteSpace(_notificationOptions.Smtp.Host))
        {
            throw new ProviderVerificationPreconditionException(
                "SMTP verification is not enabled with a fixed recipient and SMTP host.");
        }
        if (_notificationOptions.Smtp.Host.Trim().Equals(
                "padelclub-mailpit", StringComparison.OrdinalIgnoreCase))
        {
            throw new ProviderVerificationPreconditionException(
                "SMTP verification requires a third-party SMTP host; local Mailpit is development-only.");
        }

        return new ProviderDefinition(ProviderNames.Smtp, "SendFixedCorrelationMessage");
    }

    private ProviderDefinition ResolveFirebaseDefinition()
    {
        if (!_verificationOptions.AllowFirebase ||
            string.IsNullOrWhiteSpace(_verificationOptions.FirebaseInstallationId) ||
            string.IsNullOrWhiteSpace(_notificationOptions.FirebaseProjectId))
        {
            throw new ProviderVerificationPreconditionException(
                "Firebase verification is not enabled with a fixed installation and project.");
        }

        return new ProviderDefinition(ProviderNames.Firebase, "SendFixedCorrelationNotification");
    }

    private static ProviderVerificationAttemptResponse ToResponse(ProviderVerificationAttempt attempt) => new()
    {
        CorrelationId = attempt.CorrelationId,
        Provider = attempt.Provider,
        VerificationKind = attempt.VerificationKind,
        Status = attempt.Status,
        OutcomeCategory = attempt.OutcomeCategory,
        StartedAtUtc = attempt.StartedAtUtc,
        CompletedAtUtc = attempt.CompletedAtUtc,
        EvidenceBoundary = BoundaryFor(attempt.Provider)
    };

    private static string BoundaryFor(string provider) => provider switch
    {
        ProviderNames.Stripe => "A succeeded row proves read access to the configured Stripe test-mode object only; it is not a payment, webhook, refund, or live-provider proof.",
        ProviderNames.Smtp => "A succeeded row proves the configured SMTP server accepted a fixed verification message only; it is not inbox delivery or a read receipt.",
        ProviderNames.Firebase => "A succeeded row proves Firebase accepted a fixed verification notification only; it is not device delivery, display, or a read receipt.",
        _ => "This row is bounded provider-attempt evidence only."
    };

    private sealed record ProviderDefinition(string Provider, string VerificationKind);
}

public static class ProviderNames
{
    public const string Stripe = "stripe";
    public const string Smtp = "smtp";
    public const string Firebase = "firebase";
}
