using PadelClub.WebAPI.Workflows;
using PadelClub.Model.Requests;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PadelClub.Services;
using PadelClub.WebAPI.PlayerExperience;
using PadelClub.WebAPI.Tournaments;

namespace PadelClub.WebAPI.Controllers;

[ApiController]
[Route("[controller]")]
[Authorize(Policy = "VerifiedPlayer")]
public sealed class PlayerExperienceController(PlayerExperienceWorkflow workflow) : ControllerBase
{
    [HttpGet("cities")]
    public async Task<ActionResult<object>> Cities(CancellationToken ct) => (await workflow.Cities(ct)).ToHttp();

    [HttpGet("profile/mine")]
    public async Task<ActionResult<object>> Profile(CancellationToken ct) => (await workflow.Profile(ct)).ToHttp();

    [HttpPut("profile/mine")]
    public async Task<ActionResult<object>> SaveProfile(PlayerProfileRequest request, CancellationToken ct) => (await workflow.SaveProfile(request, ct)).ToHttp();

    [HttpGet("partners")]
    public async Task<ActionResult<object>> Partners([FromQuery] string? skillLevel, [FromQuery] string? city, [FromQuery] string? query, CancellationToken ct) => (await workflow.Partners(skillLevel, city, query, ct)).ToHttp();

    [HttpPost("partners/{recipientUserId:int}/invite")]
    public async Task<ActionResult<object>> Invite(int recipientUserId, PartnerInviteRequest request, CancellationToken ct) => (await workflow.Invite(recipientUserId, request, ct)).ToHttp();

    [HttpGet("invitations/mine")]
    public async Task<ActionResult<object>> Invitations(CancellationToken ct) => (await workflow.Invitations(ct)).ToHttp();

    [HttpPut("invitations/{id:int}/respond")]
    public async Task<IActionResult> Respond(int id, PartnerInviteResponse request, CancellationToken ct) => (await workflow.Respond(id, request, ct)).ToHttp();

    [HttpGet("matches/mine")]
    public async Task<ActionResult<object>> MatchHistory(CancellationToken ct) => (await workflow.MatchHistory(ct)).ToHttp();

    [HttpPost("matches/{matchId:int}/result")]
    public async Task<IActionResult> ReportResult(int matchId, MatchResultRequest request, CancellationToken ct) => (await workflow.ReportResult(matchId, request, ct)).ToHttp();

    [HttpPost("matches/{matchId:int}/confirm")]
    public async Task<IActionResult> ConfirmResult(int matchId, CancellationToken ct) => (await workflow.ConfirmResult(matchId, ct)).ToHttp();
}
