using PadelClub.Model.Responses;

namespace PadelClub.WebAPI.Discovery;

public interface IDiscoveryService
{
    Task<List<MatchSummaryResponse>> GetMatchesAsync(string? query, CancellationToken cancellationToken);
    Task<List<PlayerRankingResponse>> GetRankingsAsync(string? query, CancellationToken cancellationToken);
}