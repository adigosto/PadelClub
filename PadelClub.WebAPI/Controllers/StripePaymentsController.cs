using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Services.Database;
using PadelClub.WebAPI.Filters;
using PadelClub.WebAPI.Payments;
using Stripe;

namespace PadelClub.WebAPI.Controllers;

[ApiController]
[Route("StripePayments")]
[Authorize]
public sealed class StripePaymentsController(
    IStripePaymentService payments,
    IProviderRefundOperationService refundOperations,
    IOptions<StripeOptions> options,
    IMobilePaymentService mobilePayments) : ControllerBase
{
    [HttpGet("configuration")]
    public object Configuration() => new {
        PublishableKey = options.Value.PublishableKey,
        Available = options.Value.PublishableKey.StartsWith("pk_") && !string.IsNullOrWhiteSpace(options.Value.SecretKey) && !string.IsNullOrWhiteSpace(options.Value.WebhookSecret)
    };

    [HttpGet("payables")]
    public Task<List<PayableResponse>> Payables([FromQuery] string type = "Order", [FromQuery] int page = 1, CancellationToken ct = default) =>
        mobilePayments.GetPayablesAsync(CurrentUserId(), type, page, ct);

    [HttpGet("{paymentId:int}/status")]
    public async Task<ActionResult<PaymentStateResponse>> Status(int paymentId, CancellationToken ct) =>
        await mobilePayments.GetStateAsync(CurrentUserId(), paymentId, ct) is { } state ? Ok(state) : NotFound();

    [HttpPost("intent")]
    public Task<StripePaymentResponse> CreateIntent(CreateStripePaymentRequest request, CancellationToken cancellationToken) =>
        payments.CreateIntentAsync(CurrentUserId(), request, cancellationToken);

    [HttpPost("{paymentId:int}/refund")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<ActionResult<ProviderRefundOperationResponse>> Refund(int paymentId, StripeRefundRequest request, CancellationToken cancellationToken)
    {
        var operation = await refundOperations.QueueDirectAsync(paymentId, CurrentUserId(), request, cancellationToken);
        return AcceptedAtAction(nameof(GetRefundOperation), new { operationId = operation.Id }, ToResponse(operation));
    }

    [HttpGet("refunds/{operationId:guid}")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<ActionResult<ProviderRefundOperationResponse>> GetRefundOperation(Guid operationId, CancellationToken cancellationToken)
    {
        var operation = await refundOperations.GetAsync(operationId, cancellationToken);
        return operation is null ? NotFound() : Ok(operation);
    }

    private int CurrentUserId() => int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : throw new UnauthorizedAccessException();

    private static ProviderRefundOperationResponse ToResponse(ProviderRefundOperation operation) => new()
    {
        Id = operation.Id,
        PaymentId = operation.PaymentId,
        ReturnRequestId = operation.ReturnRequestId,
        Amount = operation.Amount,
        Currency = operation.Currency,
        Provider = operation.Provider,
        Status = operation.Status,
        ProviderRefundId = operation.ProviderRefundId,
        AttemptCount = operation.AttemptCount,
        NextAttemptAtUtc = operation.NextAttemptAtUtc,
        LastError = operation.LastError,
        CreatedAtUtc = operation.CreatedAtUtc,
        ProviderAcceptedAtUtc = operation.ProviderAcceptedAtUtc,
        CompletedAtUtc = operation.CompletedAtUtc
    };
}

[ApiController]
[Route("StripePayments")]
[ServiceFilter(typeof(StripeWebhookSignatureFilter))]
public sealed class StripeWebhookController(IStripePaymentService payments, IOptions<StripeOptions> options) : ControllerBase
{
    [HttpPost("webhook")]
    [RequestSizeLimit(1_048_576)]
    public async Task<IActionResult> Webhook(CancellationToken cancellationToken)
    {
        using var reader = new StreamReader(Request.Body);
        var payload = await reader.ReadToEndAsync(cancellationToken);
        try
        {
            var stripeEvent = EventUtility.ConstructEvent(payload, Request.Headers["Stripe-Signature"], options.Value.WebhookSecret);
            await payments.ProcessWebhookAsync(stripeEvent, cancellationToken);
            return Ok();
        }
        catch (StripeException)
        {
            return BadRequest("Invalid Stripe webhook signature or payload.");
        }
    }
}
