namespace PadelClub.Model.Requests;

/// <summary>
/// The only client-controlled input for an external rehearsal. Provider
/// target values always come from server configuration so an administrator
/// cannot use this endpoint as an arbitrary mail, push, or Stripe relay.
/// </summary>
public sealed class ProviderVerificationRequest
{
    public bool ConfirmExternalCall { get; set; }
}
