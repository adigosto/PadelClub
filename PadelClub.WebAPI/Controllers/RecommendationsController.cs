using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Services.Recommendations;

namespace PadelClub.WebAPI.Controllers;

[ApiController]
[Route("[controller]")]
[Authorize]
public sealed class RecommendationsController(
    IProductRecommendationService recommendations,
    IRecommendationExperimentService experiments) : ControllerBase
{
    [HttpGet("products")]
    public async Task<ActionResult<IReadOnlyList<ProductRecommendationResponse>>> Products(
        [FromQuery] int limit = 6,
        CancellationToken cancellationToken = default)
    {
        var userId = int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var parsedUserId)
            ? parsedUserId
            : throw new UnauthorizedAccessException("The authenticated user identifier is invalid.");

        return Ok(await recommendations.GetForUserAsync(userId, Math.Clamp(limit, 1, 12), cancellationToken));
    }

    /// <summary>
    /// Records an intentional player interaction with an individual
    /// server-issued recommendation exposure. The opaque identifier is scoped
    /// to the authenticated owner, so it cannot be used to inspect or affect
    /// another player's telemetry.
    /// </summary>
    [HttpPost("products/{exposureId:guid}/click")]
    public async Task<IActionResult> ProductClick(
        Guid exposureId,
        CancellationToken cancellationToken = default)
    {
        var userId = int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var parsedUserId)
            ? parsedUserId
            : throw new UnauthorizedAccessException("The authenticated user identifier is invalid.");

        return await recommendations.RecordClickAsync(userId, exposureId, cancellationToken)
            ? NoContent()
            : NotFound();
    }

    /// <summary>
    /// Shows the authenticated player's explicit recommendation-analytics
    /// choice. Notification preferences are deliberately not treated as this
    /// consent because delivery preference and experiment telemetry are
    /// separate choices.
    /// </summary>
    [HttpGet("analytics-consent")]
    public Task<ActionResult<RecommendationAnalyticsConsentResponse>> AnalyticsConsent(
        CancellationToken cancellationToken = default) => GetConsentAsync(cancellationToken);

    /// <summary>
    /// Grants or revokes prospective experiment telemetry. Revocation stops
    /// future assignment/serving; it does not rewrite already recorded
    /// append-only evidence.
    /// </summary>
    [HttpPut("analytics-consent")]
    public async Task<ActionResult<RecommendationAnalyticsConsentResponse>> SetAnalyticsConsent(
        RecommendationAnalyticsConsentRequest request,
        CancellationToken cancellationToken = default) => Ok(await experiments.SetConsentAsync(
            CurrentUserId(), request.IsGranted, cancellationToken));

    private async Task<ActionResult<RecommendationAnalyticsConsentResponse>> GetConsentAsync(
        CancellationToken cancellationToken) => Ok(await experiments.GetConsentAsync(
            CurrentUserId(), cancellationToken));

    private int CurrentUserId() => int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var parsedUserId)
        ? parsedUserId
        : throw new UnauthorizedAccessException("The authenticated user identifier is invalid.");
}
