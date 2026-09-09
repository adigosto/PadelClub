using System;
using PadelClub.Model.Responses;

namespace PadelClub.Services.Recommendations;

public interface IRecommendationImpactService
{
    Task<RecommendationImpactResponse> GetAsync(
        DateTimeOffset fromUtc,
        DateTimeOffset toUtc,
        CancellationToken cancellationToken = default);
}
