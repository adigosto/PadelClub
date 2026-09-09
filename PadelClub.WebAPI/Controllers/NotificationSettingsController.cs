using PadelClub.WebAPI.Workflows;
using PadelClub.Model.Requests;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace PadelClub.WebAPI.Controllers;

[ApiController]
[Route("[controller]")]
[Authorize]
public sealed class NotificationSettingsController(NotificationSettingsWorkflow workflow) : ControllerBase
{
    [HttpGet("mine")]
    public async Task<ActionResult<NotificationPreferenceResponse>> Mine(CancellationToken cancellationToken) => (await workflow.Mine(cancellationToken)).ToHttp();

    [HttpPut("mine")]
    public async Task<ActionResult<NotificationPreferenceResponse>> SaveMine(NotificationPreferenceRequest request, CancellationToken cancellationToken) => (await workflow.SaveMine(request, cancellationToken)).ToHttp();

    [HttpPost("devices")]
    public async Task<IActionResult> RegisterDevice(PushDeviceRequest request, CancellationToken cancellationToken) => (await workflow.RegisterDevice(request, cancellationToken)).ToHttp();

    [HttpDelete("devices")]
    public async Task<IActionResult> UnregisterDevice([FromQuery] string installationId, CancellationToken cancellationToken) => (await workflow.UnregisterDevice(installationId, cancellationToken)).ToHttp();

    [HttpGet("deliveries")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<ActionResult<object>> Deliveries([FromQuery] string? status, CancellationToken cancellationToken) => (await workflow.Deliveries(status, cancellationToken)).ToHttp();
}
