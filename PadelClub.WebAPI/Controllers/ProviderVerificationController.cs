using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.WebAPI.ProviderVerification;

namespace PadelClub.WebAPI.Controllers;

/// <summary>
/// Explicit opt-in boundary for bounded external rehearsals. The endpoint has
/// no user-supplied provider target and default configuration denies every
/// call, so it cannot become a generic outbound relay.
/// </summary>
[ApiController]
[Route("Operations/provider-verification")]
[Authorize(Policy = "AdminOnly")]
public sealed class ProviderVerificationController(IProviderVerificationService verification) : ControllerBase
{
    [HttpGet]
    public Task<IReadOnlyList<ProviderVerificationAttemptResponse>> Recent(
        CancellationToken cancellationToken) => verification.GetRecentAsync(cancellationToken);

    [HttpPost("{provider}")]
    public async Task<ActionResult<ProviderVerificationAttemptResponse>> Verify(
        string provider,
        ProviderVerificationRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            var attempt = await verification.VerifyAsync(
                CurrentUserId(), provider, request, cancellationToken);
            return Ok(attempt);
        }
        catch (ProviderVerificationPreconditionException exception)
        {
            return Conflict(exception.Message);
        }
        catch (ArgumentException exception)
        {
            return BadRequest(exception.Message);
        }
    }

    private int CurrentUserId() => int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id)
        ? id
        : throw new UnauthorizedAccessException("The authenticated user identifier is invalid.");
}
