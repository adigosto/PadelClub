using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PadelClub.Model.Responses;
using PadelClub.Services.Recommendations;

namespace PadelClub.WebAPI.Controllers;

/// <summary>
/// Administrator controls for the one pre-registered prospective product
/// experiment. There is intentionally no generic experiment editor: changing
/// the treatment, control, allocation, or metric after collection begins
/// would invalidate the causal-evidence protocol.
/// </summary>
[ApiController]
[Route("Operations/recommendations/experiments")]
[Authorize(Policy = "AdminOnly")]
public sealed class RecommendationExperimentsController(
    IRecommendationExperimentService experiments) : ControllerBase
{
    [HttpPost]
    public async Task<ActionResult<RecommendationExperimentResponse>> Create(
        CancellationToken cancellationToken)
    {
        try
        {
            var experiment = await experiments.CreateAsync(CurrentUserId(), cancellationToken);
            return CreatedAtAction(nameof(Get), new { experimentId = experiment.Id }, experiment);
        }
        catch (InvalidOperationException exception)
        {
            return Conflict(exception.Message);
        }
    }

    [HttpGet("{experimentId:guid}")]
    public async Task<ActionResult<RecommendationExperimentResponse>> Get(
        Guid experimentId,
        CancellationToken cancellationToken)
    {
        var experiment = await experiments.GetAsync(experimentId, cancellationToken);
        return experiment is null ? NotFound() : Ok(experiment);
    }

    [HttpPost("{experimentId:guid}/start")]
    public Task<ActionResult<RecommendationExperimentResponse>> Start(
        Guid experimentId,
        CancellationToken cancellationToken) => ProgressLifecycleAsync(
            () => experiments.StartAsync(experimentId, cancellationToken));

    [HttpPost("{experimentId:guid}/close")]
    public Task<ActionResult<RecommendationExperimentResponse>> Close(
        Guid experimentId,
        CancellationToken cancellationToken) => ProgressLifecycleAsync(
            () => experiments.CloseAsync(experimentId, cancellationToken));

    [HttpGet("{experimentId:guid}/impact")]
    public async Task<ActionResult<RecommendationExperimentImpactResponse>> Impact(
        Guid experimentId,
        CancellationToken cancellationToken)
    {
        var report = await experiments.GetImpactAsync(experimentId, cancellationToken);
        return report is null ? NotFound() : Ok(report);
    }

    [HttpPost("{experimentId:guid}/analysis-runs")]
    public async Task<ActionResult<RecommendationExperimentAnalysisRunResponse>> CreateAnalysisRun(
        Guid experimentId,
        CancellationToken cancellationToken)
    {
        var run = await experiments.CreateAnalysisRunAsync(CurrentUserId(), experimentId, cancellationToken);
        return run is null
            ? NotFound()
            : CreatedAtAction(nameof(GetLatestAnalysisRun), new { experimentId }, run);
    }

    [HttpGet("{experimentId:guid}/analysis-runs/latest")]
    public async Task<ActionResult<RecommendationExperimentAnalysisRunResponse>> GetLatestAnalysisRun(
        Guid experimentId,
        CancellationToken cancellationToken)
    {
        var run = await experiments.GetLatestAnalysisRunAsync(experimentId, cancellationToken);
        return run is null ? NotFound() : Ok(run);
    }

    private async Task<ActionResult<RecommendationExperimentResponse>> ProgressLifecycleAsync(
        Func<Task<RecommendationExperimentResponse>> action)
    {
        try
        {
            return Ok(await action());
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
        catch (InvalidOperationException exception)
        {
            return Conflict(exception.Message);
        }
    }

    private int CurrentUserId() => int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var userId)
        ? userId
        : throw new UnauthorizedAccessException("The authenticated user identifier is invalid.");
}
