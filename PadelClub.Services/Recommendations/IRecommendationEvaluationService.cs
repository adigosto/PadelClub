using PadelClub.Model.Requests;
using PadelClub.Model.Responses;

namespace PadelClub.Services.Recommendations;

public interface IRecommendationEvaluationService
{
    Task<RecommendationEvaluationResponse> EvaluateAsync(
        RecommendationEvaluationRequest request,
        CancellationToken cancellationToken = default);

    Task<RecommendationEvaluationRunResponse> CreateRunAsync(
        int executedByUserId,
        RecommendationEvaluationRequest request,
        CancellationToken cancellationToken = default);

    Task<RecommendationEvaluationRunResponse?> GetRunAsync(
        Guid runId,
        CancellationToken cancellationToken = default);

    Task<RecommendationEvaluationRunResponse?> GetLatestRunAsync(
        CancellationToken cancellationToken = default);
}
