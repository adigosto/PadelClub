using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PadelClub.Model.Responses;
using PadelClub.Services.Database;

namespace PadelClub.WebAPI.Controllers
{
    [ApiController]
    [Route("[controller]")]
    [Authorize]
    public class DiscoveryController : ControllerBase
    {
        private readonly PadelClubContext _context;

        public DiscoveryController(PadelClubContext context)
        {
            _context = context;
        }

        [HttpGet("matches")]
        public async Task<List<MatchSummaryResponse>> Matches([FromQuery] string? query)
        {
            var matches = _context.Matches.AsNoTracking()
                .Include(x => x.Tournament)
                .Include(x => x.Court)
                .Include(x => x.Participants).ThenInclude(x => x.User)
                .AsQueryable();
            if (!string.IsNullOrWhiteSpace(query))
            {
                var term = query.Trim();
                matches = matches.Where(x =>
                    x.Tournament.Name.Contains(term) ||
                    x.Court.Name.Contains(term) ||
                    x.Status.Contains(term) ||
                    x.Participants.Any(p =>
                        p.User.FirstName.Contains(term) || p.User.LastName.Contains(term)));
            }
            return await matches.OrderByDescending(x => x.ScheduledTime).Take(30)
                .Select(x => new MatchSummaryResponse
                {
                    Id = x.Id,
                    TournamentName = x.Tournament.Name,
                    CourtName = x.Court.Name,
                    ScheduledTime = x.ScheduledTime,
                    Status = x.Status,
                    Score = x.Score,
                    TeamOne = x.Participants.Where(p => p.TeamNumber == 1)
                        .Select(p => p.User.FirstName + " " + p.User.LastName).ToList(),
                    TeamTwo = x.Participants.Where(p => p.TeamNumber == 2)
                        .Select(p => p.User.FirstName + " " + p.User.LastName).ToList()
                }).ToListAsync();
        }

        [HttpGet("rankings")]
        public async Task<List<PlayerRankingResponse>> Rankings([FromQuery] string? query)
        {
            var players = _context.Users.AsNoTracking()
                .Where(x => x.IsActive && x.UserRoles.Any(r => r.Role.Name == "Player"));
            if (!string.IsNullOrWhiteSpace(query))
            {
                var term = query.Trim();
                players = players.Where(x =>
                    x.FirstName.Contains(term) || x.LastName.Contains(term) || x.Username.Contains(term));
            }
            return await players.Select(x => new PlayerRankingResponse
                {
                    UserId = x.Id,
                    PlayerName = x.FirstName + " " + x.LastName,
                    MatchesPlayed = x.MatchParticipants.Count(p => p.Match.Status == "Completed"),
                    Wins = x.MatchParticipants.Count(p =>
                        p.Match.Status == "Completed" && p.Match.WinnerTeamId == p.TeamNumber),
                    Rating = x.PlayerProfile == null ? 1000 : x.PlayerProfile.Rating,
                    WinRate = x.MatchParticipants.Count(p => p.Match.Status == "Completed") == 0 ? 0 :
                        100.0 * x.MatchParticipants.Count(p => p.Match.Status == "Completed" && p.Match.WinnerTeamId == p.TeamNumber) /
                        x.MatchParticipants.Count(p => p.Match.Status == "Completed")
                })
                .OrderByDescending(x => x.Rating)
                .ThenByDescending(x => x.Wins)
                .ThenByDescending(x => x.MatchesPlayed)
                .ThenBy(x => x.PlayerName)
                .Take(50)
                .ToListAsync();
        }
    }
}
