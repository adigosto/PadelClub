namespace PadelClub.WebAPI.Authentication;

public static class StartupSecurity
{
    public static bool IsValidSigningKey(string? key) =>
        !string.IsNullOrWhiteSpace(key) && key.Length >= 32 &&
        !key.Contains("DEVELOPMENT-ONLY", StringComparison.OrdinalIgnoreCase) &&
        !key.Contains("CHANGE-ME", StringComparison.OrdinalIgnoreCase) &&
        !key.Contains("CHANGE-VIA-ENVIRONMENT", StringComparison.OrdinalIgnoreCase);

    public static bool ShouldSeedDemoData(string environment, bool requested) =>
        requested && string.Equals(environment, "Development", StringComparison.OrdinalIgnoreCase);
}
