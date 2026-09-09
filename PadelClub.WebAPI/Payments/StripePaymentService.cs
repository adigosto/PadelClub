using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Services.Database;
using Stripe;

namespace PadelClub.WebAPI.Payments;

public sealed class StripePaymentService(PadelClubContext db, IOptions<StripeOptions> options) : IStripePaymentService
{
    private readonly StripeOptions _options = options.Value;

    public async Task<StripePaymentResponse> CreateIntentAsync(int userId, CreateStripePaymentRequest request, CancellationToken cancellationToken)
    {
        EnsureConfigured();
        var references = new[] { request.ReservationId, request.MembershipId, request.OrderId }.Count(x => x.HasValue);
        if (references != 1) throw new InvalidOperationException("Exactly one reservation, membership, or order is required.");

        var existing = await db.Payments.AsNoTracking().SingleOrDefaultAsync(x => x.IdempotencyKey == request.IdempotencyKey, cancellationToken);
        existing ??= await db.Payments.AsNoTracking().SingleOrDefaultAsync(x =>
            (request.ReservationId.HasValue && x.ReservationId == request.ReservationId) ||
            (request.OrderId.HasValue && x.OrderId == request.OrderId) ||
            (request.MembershipId.HasValue && x.MembershipId == request.MembershipId), cancellationToken);
        if (existing is not null)
        {
            if (existing.ReservationId != request.ReservationId || existing.OrderId != request.OrderId || existing.MembershipId != request.MembershipId)
                throw new InvalidOperationException("Idempotency key belongs to a different payment request.");
            if (existing.Provider != "Stripe") throw new InvalidOperationException("This payment uses another provider.");
            if (existing.UserId != userId) throw new InvalidOperationException("Idempotency key is already in use.");
            if (!string.IsNullOrWhiteSpace(existing.TransactionId))
            {
                var existingIntent = await new PaymentIntentService(new StripeClient(_options.SecretKey)).GetAsync(existing.TransactionId, cancellationToken: cancellationToken);
                return ToResponse(existing, existingIntent);
            }
        }

        var (amount, type, description) = await ResolvePayableAsync(userId, request, cancellationToken);
        if (amount <= 0) throw new InvalidOperationException("Payment amount must be positive.");
        var payment = existing is null
            ? new Payment { UserId = userId, ReservationId = request.ReservationId, MembershipId = request.MembershipId, OrderId = request.OrderId, PaymentType = type, PaymentMethod = "Stripe", Provider = "Stripe", Currency = _options.Currency.ToLowerInvariant(), Amount = amount, Status = "Pending", IdempotencyKey = request.IdempotencyKey }
            : await db.Payments.SingleAsync(x => x.Id == existing.Id, cancellationToken);
        if (existing is not null && (payment.ReservationId != request.ReservationId || payment.MembershipId != request.MembershipId || payment.OrderId != request.OrderId || payment.Amount != amount))
            throw new InvalidOperationException("Idempotency key belongs to a different payment request.");
        if (existing is null) { db.Payments.Add(payment); await db.SaveChangesAsync(cancellationToken); }

        var email = await db.Users.Where(x => x.Id == userId).Select(x => x.Email).SingleAsync(cancellationToken);
        var createOptions = new PaymentIntentCreateOptions
        {
            Amount = checked((long)decimal.Round(amount * 100m, 0)), Currency = payment.Currency,
            Description = description, ReceiptEmail = email,
            AutomaticPaymentMethods = new PaymentIntentAutomaticPaymentMethodsOptions { Enabled = true },
            Metadata = new Dictionary<string, string> { ["payment_id"] = payment.Id.ToString(), ["user_id"] = userId.ToString(), ["payment_type"] = type }
        };
        try
        {
            var intent = await new PaymentIntentService(new StripeClient(_options.SecretKey)).CreateAsync(createOptions, new RequestOptions { IdempotencyKey = $"padelclub-payment-{payment.Id}" }, cancellationToken);
            payment.TransactionId = intent.Id;
            payment.Status = "Pending";
            payment.FailureMessage = null;
            await db.SaveChangesAsync(cancellationToken);
            return ToResponse(payment, intent);
        }
        catch (Exception ex)
        {
            payment.Status = "InitiationFailed";
            payment.FailureMessage = ex.Message;
            await db.SaveChangesAsync(cancellationToken);
            throw;
        }
    }

    public async Task ProcessWebhookAsync(Event stripeEvent, CancellationToken cancellationToken)
    {
        var record = await db.StripeWebhookEvents.SingleOrDefaultAsync(x => x.StripeEventId == stripeEvent.Id, cancellationToken);
        if (record?.ProcessedAt is not null) return;
        if (record is null)
        {
            record = new StripeWebhookEvent { StripeEventId = stripeEvent.Id, EventType = stripeEvent.Type };
            db.StripeWebhookEvents.Add(record);
        }

        try
        {
            switch (stripeEvent.Data.Object)
            {
                case PaymentIntent intent:
                    var payment = await db.Payments.SingleOrDefaultAsync(x => x.TransactionId == intent.Id, cancellationToken);
                    if (payment is null) throw new InvalidOperationException($"Stripe payment intent '{intent.Id}' is not linked to a local payment.");
                    var nextStatus = intent.Status switch { "succeeded" => "Completed", "canceled" => "Cancelled", "requires_payment_method" when intent.LastPaymentError is not null => "Failed", _ => "Pending" };
                    if (CanAdvanceStatus(payment.Status, nextStatus)) payment.Status = nextStatus;
                    if (nextStatus == "Failed") payment.FailureMessage = intent.LastPaymentError?.Message;
                    payment.ReconciledAt = DateTime.UtcNow;
                    break;
                case Charge charge when !string.IsNullOrWhiteSpace(charge.PaymentIntentId):
                    var chargePayment = await db.Payments.SingleOrDefaultAsync(x => x.TransactionId == charge.PaymentIntentId, cancellationToken);
                    if (chargePayment is null) throw new InvalidOperationException($"Stripe charge '{charge.Id}' is not linked to a local payment.");
                    chargePayment.ReceiptUrl = charge.ReceiptUrl;
                    var refundedAmount = Math.Max(chargePayment.RefundedAmount, charge.AmountRefunded / 100m);
                    if (refundedAmount > chargePayment.RefundedAmount)
                    {
                        chargePayment.RefundedAmount = refundedAmount;
                        if (refundedAmount >= chargePayment.Amount)
                            chargePayment.Status = "Refunded";
                        else if (chargePayment.Status != "Refunded")
                            chargePayment.Status = "PartiallyRefunded";
                    }
                    chargePayment.ReconciledAt = DateTime.UtcNow;
                    break;
                case Refund refund when !string.IsNullOrWhiteSpace(refund.PaymentIntentId):
                    var refundPayment = await db.Payments.SingleOrDefaultAsync(x => x.TransactionId == refund.PaymentIntentId, cancellationToken);
                    if (refundPayment is null) throw new InvalidOperationException($"Stripe refund '{refund.Id}' is not linked to a local payment.");
                    refundPayment.ReconciledAt = DateTime.UtcNow;
                    break;
            }
            record.ProcessedAt = DateTime.UtcNow;
            record.ProcessingError = null;
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (Exception ex)
        {
            record.ProcessingError = ex.Message;
            await db.SaveChangesAsync(cancellationToken);
            throw;
        }
    }

    private static bool CanAdvanceStatus(string current, string next) =>
        StatusRank(next) >= StatusRank(current) && !(current is "Completed" or "Cancelled" or "Refunded" or "PartiallyRefunded");

    private static int StatusRank(string status) => status switch
    {
        "Pending" => 0,
        "Failed" => 1,
        "Cancelled" => 2,
        "Completed" => 3,
        "PartiallyRefunded" or "Refunded" => 4,
        _ => -1
    };

    private async Task<(decimal Amount, string Type, string Description)> ResolvePayableAsync(int userId, CreateStripePaymentRequest request, CancellationToken cancellationToken)
    {
        if (request.ReservationId is int reservationId)
        {
            var item = await db.Reservations.Where(x => x.Id == reservationId && x.UserId == userId && x.Status != "Cancelled").Select(x => new { x.TotalPrice }).SingleOrDefaultAsync(cancellationToken) ?? throw new InvalidOperationException("Reservation was not found.");
            return (item.TotalPrice, "Reservation", $"PadelClub reservation #{reservationId}");
        }
        if (request.MembershipId is int membershipId)
        {
            var item = await db.Memberships.Where(x => x.Id == membershipId && x.UserId == userId && x.IsActive).Select(x => new { x.Price }).SingleOrDefaultAsync(cancellationToken) ?? throw new InvalidOperationException("Membership was not found.");
            return (item.Price, "Membership", $"PadelClub membership #{membershipId}");
        }
        var orderId = request.OrderId!.Value;
        var order = await db.Orders.Where(x => x.Id == orderId && x.UserId == userId && x.Status != "Cancelled").Select(x => new { x.TotalAmount }).SingleOrDefaultAsync(cancellationToken) ?? throw new InvalidOperationException("Order was not found.");
        return (order.TotalAmount, "Order", $"PadelClub order #{orderId}");
    }

    private static StripePaymentResponse ToResponse(Payment payment, PaymentIntent intent) => new() { PaymentId = payment.Id, PaymentIntentId = intent.Id, ClientSecret = intent.ClientSecret, Amount = payment.Amount, Currency = payment.Currency, Status = intent.Status };

    private void EnsureConfigured()
    {
        if (string.IsNullOrWhiteSpace(_options.SecretKey)) throw new InvalidOperationException("Stripe is not configured. Set Stripe__SecretKey.");
    }
}
