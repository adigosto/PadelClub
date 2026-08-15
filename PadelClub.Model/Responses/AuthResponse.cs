using System;

namespace PadelClub.Model.Responses;

public sealed class AuthResponse
{
    public string AccessToken { get; set; } = string.Empty;
    public string RefreshToken { get; set; } = string.Empty;
    public DateTime AccessTokenExpiresAt { get; set; }
    public UserResponse User { get; set; } = null!;
}
