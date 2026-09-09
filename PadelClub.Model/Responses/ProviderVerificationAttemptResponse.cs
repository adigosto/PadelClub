using System;

namespace PadelClub.Model.Responses;

/// <summary>
/// Safe administrative evidence of an opt-in provider rehearsal. A succeeded
/// row proves only the named provider accepted the bounded test action; it
/// does not prove recipient receipt, production customer impact, or a
/// distributed transaction.
/// </summary>
public sealed class ProviderVerificationAttemptResponse
{
    public Guid CorrelationId { get; init; }

    public string Provider { get; init; } = string.Empty;

    public string VerificationKind { get; init; } = string.Empty;

    public string Status { get; init; } = string.Empty;

    public string OutcomeCategory { get; init; } = string.Empty;

    public DateTime StartedAtUtc { get; init; }

    public DateTime? CompletedAtUtc { get; init; }

    public string EvidenceBoundary { get; init; } = string.Empty;
}
