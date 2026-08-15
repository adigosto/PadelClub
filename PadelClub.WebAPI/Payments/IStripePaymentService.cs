using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Model;
using Stripe;

namespace PadelClub.WebAPI.Payments;

public interface IStripePaymentService
{
    Task<StripePaymentResponse> CreateIntentAsync(int userId, CreateStripePaymentRequest request, CancellationToken cancellationToken);
    Task ProcessWebhookAsync(Event stripeEvent, CancellationToken cancellationToken);
    Task<PaymentResponse> RefundAsync(int paymentId, StripeRefundRequest request, CancellationToken cancellationToken);
}
