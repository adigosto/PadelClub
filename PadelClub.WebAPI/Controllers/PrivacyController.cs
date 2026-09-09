using PadelClub.WebAPI.Workflows;
using PadelClub.Model.Requests;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace PadelClub.WebAPI.Controllers;

[ApiController]
[Route("Privacy")]
[Authorize]
public sealed class PrivacyController(PrivacyWorkflow workflow) : ControllerBase
{
    [HttpGet("export")]
    public async Task<ActionResult<object>> Export(CancellationToken ct) => (await workflow.Export(ct)).ToHttp();

    [HttpPost("deletion")]
    public async Task<ActionResult<object>> RequestDeletion(CancellationToken ct) => (await workflow.RequestDeletion(ct)).ToHttp();

    [HttpDelete("deletion")]
    public async Task<IActionResult> CancelDeletion(CancellationToken ct) => (await workflow.CancelDeletion(ct)).ToHttp();

    [HttpGet("deletion")]
    public async Task<ActionResult<object>> DeletionStatus(CancellationToken ct) => (await workflow.DeletionStatus(ct)).ToHttp();
}
