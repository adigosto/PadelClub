using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.WebAPI.Payments;
using Stripe;

namespace PadelClub.WebAPI.Controllers;

[ApiController]
[Route("StripePayments")]
[Authorize]
public sealed class StripePaymentsController(IStripePaymentService payments, IOptions<StripeOptions> options) : ControllerBase
{
    [HttpPost("intent")]
    public Task<StripePaymentResponse> CreateIntent(CreateStripePaymentRequest request, CancellationToken cancellationToken) =>
        payments.CreateIntentAsync(CurrentUserId(), request, cancellationToken);

    [HttpPost("{paymentId:int}/refund")]
    [Authorize(Policy = "AdminOnly")]
    public Task<PaymentResponse> Refund(int paymentId, StripeRefundRequest request, CancellationToken cancellationToken) =>
        payments.RefundAsync(paymentId, request, cancellationToken);

    [HttpPost("webhook")]
    [AllowAnonymous]
    [RequestSizeLimit(1_048_576)]
    public async Task<IActionResult> Webhook(CancellationToken cancellationToken)
    {
        var configuration = options.Value;
        if (string.IsNullOrWhiteSpace(configuration.WebhookSecret)) return Problem("Stripe webhook is not configured.", statusCode: 503);
        using var reader = new StreamReader(Request.Body);
        var payload = await reader.ReadToEndAsync(cancellationToken);
        try
        {
            var stripeEvent = EventUtility.ConstructEvent(payload, Request.Headers["Stripe-Signature"], configuration.WebhookSecret);
            await payments.ProcessWebhookAsync(stripeEvent, cancellationToken);
            return Ok();
        }
        catch (StripeException)
        {
            return BadRequest("Invalid Stripe webhook signature or payload.");
        }
    }

    private int CurrentUserId() => int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : throw new UnauthorizedAccessException();
}
