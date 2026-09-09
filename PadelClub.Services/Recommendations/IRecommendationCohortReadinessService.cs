using PadelClub.Model.Responses;

namespace PadelClub.Services.Recommendations;

/// <summary>
/// Provides aggregate-only collection progress for the provenance-backed
/// operational recommendation cohort. It is deliberately separate from the
/// temporal evaluator, which alone can issue a Diagnostic or Qualified result
/// for an explicitly selected historical window.
/// </summary>
public interface IRecommendationCohortReadinessService
{
    Task<RecommendationCohortReadinessResponse> GetReadinessAsync(
        CancellationToken cancellationToken = default);
}
