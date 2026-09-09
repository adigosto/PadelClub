using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PadelClub.Model.Responses;
using PadelClub.WebAPI.Discovery;

namespace PadelClub.WebAPI.Controllers
{
    [ApiController]
    [Route("[controller]")]
    [Authorize]
    public class DiscoveryController : ControllerBase
    {
            private readonly IDiscoveryService _service;

            public DiscoveryController(IDiscoveryService service)
        {
                _service = service;
        }

        [HttpGet("matches")]
        public async Task<List<MatchSummaryResponse>> Matches([FromQuery] string? query)
        {
            return await _service.GetMatchesAsync(query, HttpContext.RequestAborted);
        }

        [HttpGet("rankings")]
        public async Task<List<PlayerRankingResponse>> Rankings([FromQuery] string? query)
        {
            return await _service.GetRankingsAsync(query, HttpContext.RequestAborted);
        }
    }
}
