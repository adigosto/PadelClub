using PadelClub.WebAPI.Workflows;
using PadelClub.Model.Requests;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PadelClub.Services;
using PadelClub.WebAPI.Tournaments;

namespace PadelClub.WebAPI.Controllers;

[ApiController]
[Route("Tournaments")]
[Authorize]
public sealed class TournamentLifecycleController(TournamentLifecycleWorkflow workflow) : ControllerBase
{
    [HttpGet("mine")]
    [Authorize(Policy = "VerifiedPlayer")]
    public async Task<ActionResult<object>> Mine(CancellationToken ct) => (await workflow.Mine(ct)).ToHttp();

    [HttpPost("{tournamentId:int}/register")]
    [Authorize(Policy = "VerifiedPlayer")]
    public async Task<IActionResult> Register(int tournamentId, TournamentTeamRegistration request, CancellationToken ct) => (await workflow.Register(tournamentId, request, ct)).ToHttp();

    [HttpPut("{tournamentId:int}/registration/respond")]
    [Authorize(Policy = "VerifiedPlayer")]
    public async Task<IActionResult> Respond(int tournamentId, TournamentRegistrationResponse request, CancellationToken ct) => (await workflow.Respond(tournamentId, request, ct)).ToHttp();

    [HttpDelete("{tournamentId:int}/registration/mine")]
    [Authorize(Policy = "VerifiedPlayer")]
    public async Task<IActionResult> Withdraw(int tournamentId, CancellationToken ct) => (await workflow.Withdraw(tournamentId, ct)).ToHttp();

    [HttpPost("{tournamentId:int}/bracket/generate")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<IActionResult> Generate(int tournamentId, CancellationToken ct) => (await workflow.Generate(tournamentId, ct)).ToHttp();

    [HttpGet("{tournamentId:int}/bracket")]
    public async Task<ActionResult<object>> Bracket(int tournamentId, CancellationToken ct) => (await workflow.Bracket(tournamentId, ct)).ToHttp();
}
