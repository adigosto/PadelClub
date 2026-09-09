namespace PadelClub.Services.Recommendations;

/// <summary>
/// Immutable server-startup environment stamp used when provenance is recorded
/// for a recommendation exposure. It deliberately has no request or client
/// input surface.
/// </summary>
public interface IRecommendationTelemetryEnvironment
{
    string EnvironmentName { get; }
}

public sealed record RecommendationTelemetryEnvironment(string EnvironmentName)
    : IRecommendationTelemetryEnvironment;
