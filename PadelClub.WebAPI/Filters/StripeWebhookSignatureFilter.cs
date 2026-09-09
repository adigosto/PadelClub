using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.Extensions.Options;
using PadelClub.WebAPI.Payments;
using Stripe;

namespace PadelClub.WebAPI.Filters;

public sealed class StripeWebhookSignatureFilter(IOptions<StripeOptions> options) : IAsyncAuthorizationFilter
{
    public async Task OnAuthorizationAsync(AuthorizationFilterContext context)
    {
        var secret = options.Value.WebhookSecret?.Trim();
        if (string.IsNullOrWhiteSpace(secret))
        {
            context.Result = new ObjectResult(new ProblemDetails { Detail = "Stripe webhook is not configured." }) { StatusCode = StatusCodes.Status503ServiceUnavailable };
            return;
        }

        context.HttpContext.Request.EnableBuffering();
        using var reader = new StreamReader(context.HttpContext.Request.Body, leaveOpen: true);
        var payload = await reader.ReadToEndAsync(context.HttpContext.RequestAborted);
        context.HttpContext.Request.Body.Position = 0;
        try
        {
            EventUtility.ConstructEvent(payload, context.HttpContext.Request.Headers["Stripe-Signature"], secret);
        }
        catch (StripeException)
        {
            context.Result = new BadRequestObjectResult("Invalid Stripe webhook signature or payload.");
        }
    }
}