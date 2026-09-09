using System;

namespace PadelClub.Model.Responses;

/// <summary>
/// A durable refund operation. A queued state means no claim is made that the
/// external provider has already accepted the refund.
/// </summary>
public sealed class ProviderRefundOperationResponse
{
    public Guid Id { get; set; }
    public int PaymentId { get; set; }
    public int? ReturnRequestId { get; set; }
    public decimal Amount { get; set; }
    public string Currency { get; set; } = string.Empty;
    public string Provider { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public string? ProviderRefundId { get; set; }
    public int AttemptCount { get; set; }
    public DateTime NextAttemptAtUtc { get; set; }
    public string? LastError { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? ProviderAcceptedAtUtc { get; set; }
    public DateTime? CompletedAtUtc { get; set; }
}
