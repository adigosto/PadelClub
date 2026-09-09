using PadelClub.Model.Responses;
using PadelClub.Services.Database;

namespace PadelClub.Services.Recommendations;

/// <summary>
/// Owns explicit consent, immutable experiment lifecycle, sticky assignment,
/// and aggregate-only analysis for the prospective recommendation experiment.
/// </summary>
public interface IRecommendationExperimentService
{
    Task<RecommendationAnalyticsConsentResponse> GetConsentAsync(
        int userId,
        CancellationToken cancellationToken = default);

    Task<RecommendationAnalyticsConsentResponse> SetConsentAsync(
        int userId,
        bool isGranted,
        CancellationToken cancellationToken = default);

    Task<RecommendationExperimentAssignmentContext?> GetActiveAssignmentAsync(
        int userId,
        RecommendationTelemetrySource telemetrySource,
        int recommendationLimit,
        CancellationToken cancellationToken = default);

    Task<RecommendationExperimentResponse> CreateAsync(
        int createdByUserId,
        CancellationToken cancellationToken = default);

    Task<RecommendationExperimentResponse?> GetAsync(
        Guid experimentId,
        CancellationToken cancellationToken = default);

    Task<RecommendationExperimentResponse> StartAsync(
        Guid experimentId,
        CancellationToken cancellationToken = default);

    Task<RecommendationExperimentResponse> CloseAsync(
        Guid experimentId,
        CancellationToken cancellationToken = default);

    Task<RecommendationExperimentImpactResponse?> GetImpactAsync(
        Guid experimentId,
        CancellationToken cancellationToken = default);

    Task<RecommendationExperimentAnalysisRunResponse?> CreateAnalysisRunAsync(
        int executedByUserId,
        Guid experimentId,
        CancellationToken cancellationToken = default);

    Task<RecommendationExperimentAnalysisRunResponse?> GetLatestAnalysisRunAsync(
        Guid experimentId,
        CancellationToken cancellationToken = default);
}

/// <summary>
/// Internal serving decision. It is never sent to the client so a player is
/// not told which arm they received.
/// </summary>
public sealed record RecommendationExperimentAssignmentContext(
    Guid AssignmentId,
    RecommendationExperimentVariant Variant,
    string AlgorithmVersion,
    string Strategy);
