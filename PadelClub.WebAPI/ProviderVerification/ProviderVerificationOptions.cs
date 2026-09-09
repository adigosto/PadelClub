namespace PadelClub.WebAPI.ProviderVerification;

/// <summary>
/// Explicit, default-deny configuration for bounded external rehearsals.
/// Secrets and target identifiers are supplied only through deployment
/// configuration and are never returned by the API or persisted as evidence.
/// </summary>
public sealed class ProviderVerificationOptions
{
    public const string SectionName = "ProviderVerification";

    public bool Enabled { get; set; }

    public bool AllowStripeTestRead { get; set; }

    public bool AllowSmtp { get; set; }

    public bool AllowFirebase { get; set; }

    public int MinimumIntervalMinutes { get; set; } = 15;

    public string StripeTestPaymentIntentId { get; set; } = string.Empty;

    public string SmtpRecipient { get; set; } = string.Empty;

    public string FirebaseInstallationId { get; set; } = string.Empty;
}
