namespace PadelClub.WebAPI.Authentication;

public sealed class AuthOptions
{
    public const string SectionName = "Authentication";
    public string Issuer { get; set; } = "PadelClub";
    public string Audience { get; set; } = "PadelClub.Clients";
    public string SigningKey { get; set; } = string.Empty;
    public int AccessTokenMinutes { get; set; } = 15;
    public int RefreshTokenDays { get; set; } = 30;
}
