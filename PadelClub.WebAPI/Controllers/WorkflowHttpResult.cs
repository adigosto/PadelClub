using Microsoft.AspNetCore.Mvc;
using PadelClub.WebAPI.Workflows;

namespace PadelClub.WebAPI.Controllers;

internal static class WorkflowHttpResult
{
    public static ActionResult ToHttp(this WorkflowResult result) => result.Outcome switch
    {
        WorkflowOutcome.Success => new OkObjectResult(result.Value),
        WorkflowOutcome.Empty => new NoContentResult(),
        WorkflowOutcome.Missing => new NotFoundResult(),
        WorkflowOutcome.Forbidden => new ForbidResult(),
        WorkflowOutcome.Invalid => new BadRequestObjectResult(result.Value),
        WorkflowOutcome.Conflict => new ConflictObjectResult(result.Value),
        WorkflowOutcome.Accepted => new AcceptedResult((string?)null, result.Value),
        WorkflowOutcome.Created => new ObjectResult(result.Value) { StatusCode = 201 },
        _ => throw new InvalidOperationException("Unknown workflow outcome.")
    };
}
