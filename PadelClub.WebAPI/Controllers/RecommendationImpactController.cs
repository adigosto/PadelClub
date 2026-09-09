using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PadelClub.Model.Responses;
using PadelClub.Services.Recommendations;

namespace PadelClub.WebAPI.Controllers;

/// <summary>
/// Administrator-only descriptive funnel for recommendation interactions.
/// It is deliberately separate from offline evaluator evidence: it tracks
/// online exposure/click/checkout observations but has no control group.
/// </summary>
[ApiController]
[Route("Operations/recommendations/impact")]
[Authorize(Policy = "AdminOnly")]
public sealed class RecommendationImpactController(
    IRecommendationImpactService recommendationImpact) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<RecommendationImpactResponse>> Get(
        [FromQuery] DateTimeOffset? fromUtc,
        [FromQuery] DateTimeOffset? toUtc,
        CancellationToken cancellationToken)
    {
        var end = (toUtc ?? DateTimeOffset.UtcNow).ToUniversalTime();
        var start = (fromUtc ?? end.AddDays(-30)).ToUniversalTime();
        if (end <= start || end - start > TimeSpan.FromDays(366))
            return BadRequest("Choose a valid impact window of at most 366 days.");
        if (end > DateTimeOffset.UtcNow)
            return BadRequest("toUtc cannot be in the future.");

        return Ok(await recommendationImpact.GetAsync(start, end, cancellationToken));
    }
}
