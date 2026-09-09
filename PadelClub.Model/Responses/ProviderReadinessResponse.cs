namespace PadelClub.Model.Responses;

/// <summary>
/// A configuration-only summary of optional external providers.
///
/// It intentionally contains neither connection results nor any credential,
/// host, recipient, token, or service-account value. A configured state means
/// only that the local configuration has the expected shape.
/// </summary>
public sealed record ProviderReadinessResponse(
    string Assessment,
    string Caveat,
    StripeProviderReadiness Stripe,
    SmtpProviderReadiness Smtp,
    FirebaseProviderReadiness Firebase);

public sealed record StripeProviderReadiness(
    string Mode,
    string IntentState,
    string WebhookState,
    string Currency);

public sealed record SmtpProviderReadiness(string State);

public sealed record FirebaseProviderReadiness(string State);
