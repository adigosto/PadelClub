using System.ComponentModel.DataAnnotations;

namespace PadelClub.Model.Requests;

public sealed class RefreshTokenRequest { [Required, StringLength(256, MinimumLength = 32)] public string RefreshToken { get; set; } = string.Empty; }
public sealed class LogoutRequest { [Required, StringLength(256, MinimumLength = 32)] public string RefreshToken { get; set; } = string.Empty; }
public sealed class ForgotPasswordRequest { [Required, EmailAddress, StringLength(255)] public string Email { get; set; } = string.Empty; }
public sealed class ResetPasswordRequest
{
    [Required, StringLength(256, MinimumLength = 32)] public string Token { get; set; } = string.Empty;
    [Required, StringLength(256, MinimumLength = 10)] public string NewPassword { get; set; } = string.Empty;
}
public sealed class VerifyEmailRequest { [Required, StringLength(256, MinimumLength = 32)] public string Token { get; set; } = string.Empty; }
