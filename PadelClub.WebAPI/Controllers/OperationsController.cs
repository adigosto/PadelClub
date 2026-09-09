using PadelClub.WebAPI.Workflows;
using PadelClub.Model.Requests;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PadelClub.Model.Responses;
using PadelClub.Services.Recommendations;

namespace PadelClub.WebAPI.Controllers;

[ApiController]
[Route("Operations")]
[Authorize(Policy = "AdminOnly")]
public sealed class OperationsController(OperationsWorkflow workflow) : ControllerBase
{
    [HttpGet("analytics")]
    public async Task<ActionResult<object>> Analytics([FromQuery] DateTime? from, [FromQuery] DateTime? to, CancellationToken ct) => (await workflow.Analytics(from, to, ct)).ToHttp();

    [HttpGet("recommendations/evaluation")]
    public async Task<ActionResult<RecommendationEvaluationResponse>> RecommendationEvaluation(
        [FromQuery] RecommendationEvaluationRequest request,
        CancellationToken ct) => (await workflow.RecommendationEvaluation(request, ct)).ToHttp();

    [HttpGet("recommendations/cohort-readiness")]
    public async Task<ActionResult<RecommendationCohortReadinessResponse>> RecommendationCohortReadiness(
        CancellationToken ct) => (await workflow.RecommendationCohortReadiness(ct)).ToHttp();

    [HttpPost("recommendations/evaluation/runs")]
    public async Task<ActionResult<RecommendationEvaluationRunResponse>> CreateRecommendationEvaluationRun(
        [FromBody] RecommendationEvaluationRequest request,
        CancellationToken ct) {
        var result = await workflow.CreateRecommendationEvaluationRun(request, ct);
        if (result.Outcome == WorkflowOutcome.Created && result.Value is RecommendationEvaluationRunResponse run)
            return CreatedAtAction(nameof(GetRecommendationEvaluationRun), new { runId = run.RunId }, run);
        return result.ToHttp();
    }

    [HttpGet("recommendations/evaluation/runs/latest")]
    public async Task<ActionResult<RecommendationEvaluationRunResponse>> GetLatestRecommendationEvaluationRun(
        CancellationToken ct) => (await workflow.GetLatestRecommendationEvaluationRun(ct)).ToHttp();

    [HttpGet("recommendations/evaluation/runs/{runId:guid}")]
    public async Task<ActionResult<RecommendationEvaluationRunResponse>> GetRecommendationEvaluationRun(
        Guid runId,
        CancellationToken ct) => (await workflow.GetRecommendationEvaluationRun(runId, ct)).ToHttp();

    [HttpGet("audit")]
    public async Task<ActionResult<object>> Audit([FromQuery] int? userId, [FromQuery] string? method, [FromQuery] DateTime? from, CancellationToken ct, [FromQuery] string? userName = null) => (await workflow.Audit(userId, method, from, ct, userName)).ToHttp();
}
