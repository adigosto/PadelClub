using System.Net.Mail;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using PadelClub.Model.Responses;
using PadelClub.WebAPI.Notifications;
using PadelClub.WebAPI.Payments;

namespace PadelClub.WebAPI.Controllers;

/// <summary>
/// Administrator-only, configuration-shape diagnostics for optional external
/// providers. This controller never constructs a Stripe, SMTP, or Firebase
/// client, so reading it cannot send a payment or delivery attempt.
/// </summary>
[ApiController]
[Route("Operations/provider-readiness")]
[Authorize(Policy = "AdminOnly")]
public sealed class ProviderReadinessController(
    IOptions<StripeOptions> stripeOptions,
    IOptions<NotificationDeliveryOptions> notificationOptions) : ControllerBase
{
    private static readonly Regex CurrencyPattern = new("^[A-Za-z]{3}$", RegexOptions.CultureInvariant);

    [HttpGet]
    public ActionResult<ProviderReadinessResponse> Get() => Ok(new ProviderReadinessResponse(
        Assessment: "ConfigurationOnly",
        Caveat: "This reports local configuration shape only. It does not contact Stripe, SMTP, or Firebase; it does not prove a payment, external delivery, or recipient receipt.",
        Stripe: ReadStripe(stripeOptions.Value),
        Smtp: ReadSmtp(notificationOptions.Value.Smtp),
        Firebase: ReadFirebase(notificationOptions.Value)));

    private static StripeProviderReadiness ReadStripe(StripeOptions options)
    {
        var secretKey = options.SecretKey?.Trim() ?? string.Empty;
        var mode = secretKey.Length == 0
            ? "Unconfigured"
            : IsSecretWithPrefix(secretKey, "sk_test_")
                ? "Test"
                : IsSecretWithPrefix(secretKey, "sk_live_")
                    ? "Live"
                    : "Misconfigured";
        var currency = options.Currency?.Trim() ?? string.Empty;
        var validCurrency = CurrencyPattern.IsMatch(currency);
        var intentState = mode == "Unconfigured"
            ? "Disabled"
            : mode == "Misconfigured" || !validCurrency
                ? "Misconfigured"
                : "Configured";

        var webhookSecret = options.WebhookSecret?.Trim() ?? string.Empty;
        var webhookState = webhookSecret.Length == 0
            ? "Disabled"
            : IsSecretWithPrefix(webhookSecret, "whsec_")
                ? "Configured"
                : "Misconfigured";

        return new StripeProviderReadiness(
            Mode: mode,
            IntentState: intentState,
            WebhookState: webhookState,
            Currency: currency.Length == 0 ? "Unset" : currency.ToUpperInvariant());
    }

    private static SmtpProviderReadiness ReadSmtp(SmtpOptions options)
    {
        var host = options.Host?.Trim() ?? string.Empty;
        if (host.Length == 0) return new SmtpProviderReadiness("Disabled");
        if (options.Port is < 1 or > 65535 || !HasValidAddress(options.FromAddress))
            return new SmtpProviderReadiness("Misconfigured");

        // This is the deliberately safe local Compose default. It is a test
        // inbox, not evidence that a third-party SMTP recipient received mail.
        if (host.Equals("padelclub-mailpit", StringComparison.OrdinalIgnoreCase) && options.Port == 1025)
            return new SmtpProviderReadiness("Mailpit");

        return new SmtpProviderReadiness("Configured");
    }

    private static FirebaseProviderReadiness ReadFirebase(NotificationDeliveryOptions options)
    {
        var projectId = options.FirebaseProjectId?.Trim() ?? string.Empty;
        var serviceAccountJson = options.FirebaseServiceAccountJson?.Trim() ?? string.Empty;
        if (projectId.Length == 0 && serviceAccountJson.Length == 0)
            return new FirebaseProviderReadiness("Disabled");
        if (projectId.Length == 0)
            return new FirebaseProviderReadiness("Misconfigured");
        if (serviceAccountJson.Length == 0)
            return new FirebaseProviderReadiness("AdcRequested");

        try
        {
            using var document = JsonDocument.Parse(serviceAccountJson);
            var root = document.RootElement;
            if (root.ValueKind != JsonValueKind.Object ||
                !HasRequiredString(root, "type", "service_account") ||
                !HasRequiredString(root, "project_id", projectId) ||
                !HasRequiredString(root, "client_email") ||
                !HasRequiredString(root, "private_key"))
                return new FirebaseProviderReadiness("Misconfigured");
        }
        catch (JsonException)
        {
            return new FirebaseProviderReadiness("Misconfigured");
        }

        return new FirebaseProviderReadiness("ServiceAccount");
    }

    private static bool IsSecretWithPrefix(string value, string prefix) =>
        value.StartsWith(prefix, StringComparison.Ordinal) && value.Length > prefix.Length;

    private static bool HasValidAddress(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return false;
        try
        {
            var address = new MailAddress(value.Trim());
            return address.Address.Equals(value.Trim(), StringComparison.OrdinalIgnoreCase);
        }
        catch (FormatException)
        {
            return false;
        }
    }

    private static bool HasRequiredString(JsonElement objectValue, string propertyName, string? expectedValue = null)
    {
        if (!objectValue.TryGetProperty(propertyName, out var property) || property.ValueKind != JsonValueKind.String)
            return false;
        var value = property.GetString()?.Trim();
        if (string.IsNullOrWhiteSpace(value)) return false;
        return expectedValue is null || value.Equals(expectedValue, StringComparison.Ordinal);
    }
}
