namespace PadelClub.WebAPI.Workflows;

public enum WorkflowOutcome { Success, Empty, Missing, Forbidden, Invalid, Conflict, Accepted, Created }
public sealed record WorkflowResult(WorkflowOutcome Outcome, object? Value = null);
public static class WorkflowResults
{
    public static WorkflowResult Ok(object? value) => new(WorkflowOutcome.Success, value);
    public static WorkflowResult NoContent() => new(WorkflowOutcome.Empty);
    public static WorkflowResult NotFound(object? value = null) => new(WorkflowOutcome.Missing, value);
    public static WorkflowResult Forbid() => new(WorkflowOutcome.Forbidden);
    public static WorkflowResult BadRequest(object? value) => new(WorkflowOutcome.Invalid, value);
    public static WorkflowResult Conflict(object? value) => new(WorkflowOutcome.Conflict, value);
    public static WorkflowResult Accepted(object? value) => new(WorkflowOutcome.Accepted, value);
    public static WorkflowResult Created(object? value) => new(WorkflowOutcome.Created, value);
}
