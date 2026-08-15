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
        if (existing is not null)
        {
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
            var intent = await new PaymentIntentService(new StripeClient(_options.SecretKey)).CreateAsync(createOptions, new RequestOptions { IdempotencyKey = $"padelclub-{request.IdempotencyKey}" }, cancellationToken);
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
        if (await db.StripeWebhookEvents.AnyAsync(x => x.StripeEventId == stripeEvent.Id, cancellationToken)) return;
        var record = new StripeWebhookEvent { StripeEventId = stripeEvent.Id, EventType = stripeEvent.Type };
        db.StripeWebhookEvents.Add(record);
        try
        {
            switch (stripeEvent.Data.Object)
            {
                case PaymentIntent intent:
                    var payment = await db.Payments.SingleOrDefaultAsync(x => x.TransactionId == intent.Id, cancellationToken);
                    if (payment is not null)
                    {
                        payment.Status = intent.Status switch { "succeeded" => "Completed", "canceled" => "Cancelled", "requires_payment_method" when intent.LastPaymentError is not null => "Failed", _ => "Pending" };
                        payment.FailureMessage = intent.LastPaymentError?.Message;
                        payment.ReconciledAt = DateTime.UtcNow;
                    }
                    break;
                case Charge charge when !string.IsNullOrWhiteSpace(charge.PaymentIntentId):
                    var chargePayment = await db.Payments.SingleOrDefaultAsync(x => x.TransactionId == charge.PaymentIntentId, cancellationToken);
                    if (chargePayment is not null)
                    {
                        chargePayment.ReceiptUrl = charge.ReceiptUrl;
                        chargePayment.RefundedAmount = charge.AmountRefunded / 100m;
                        if (chargePayment.RefundedAmount > 0) chargePayment.Status = chargePayment.RefundedAmount >= chargePayment.Amount ? "Refunded" : "PartiallyRefunded";
                        chargePayment.ReconciledAt = DateTime.UtcNow;
                    }
                    break;
                case Refund refund when !string.IsNullOrWhiteSpace(refund.PaymentIntentId):
                    var refundPayment = await db.Payments.SingleOrDefaultAsync(x => x.TransactionId == refund.PaymentIntentId, cancellationToken);
                    if (refundPayment is not null) refundPayment.ReconciledAt = DateTime.UtcNow;
                    break;
            }
            record.ProcessedAt = DateTime.UtcNow;
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (Exception ex)
        {
            record.ProcessingError = ex.Message;
            await db.SaveChangesAsync(cancellationToken);
            throw;
        }
    }

    public async Task<PaymentResponse> RefundAsync(int paymentId, StripeRefundRequest request, CancellationToken cancellationToken)
    {
        EnsureConfigured();
        var payment = await db.Payments.SingleOrDefaultAsync(x => x.Id == paymentId && x.Provider == "Stripe", cancellationToken) ?? throw new InvalidOperationException("Stripe payment was not found.");
        if (payment.Status is not ("Completed" or "PartiallyRefunded")) throw new InvalidOperationException("Only completed Stripe payments can be refunded.");
        var amount = request.Amount ?? (payment.Amount - payment.RefundedAmount);
        if (amount <= 0 || amount > payment.Amount - payment.RefundedAmount) throw new InvalidOperationException("Invalid refund amount.");
        var refund = await new RefundService(new StripeClient(_options.SecretKey)).CreateAsync(new RefundCreateOptions
        {
            PaymentIntent = payment.TransactionId, Amount = checked((long)decimal.Round(amount * 100m, 0)), Reason = "requested_by_customer",
            Metadata = new Dictionary<string, string> { ["payment_id"] = payment.Id.ToString(), ["internal_reason"] = request.Reason }
        }, new RequestOptions { IdempotencyKey = $"refund-{payment.Id}-{payment.RefundedAmount + amount:0.00}" }, cancellationToken);
        payment.RefundedAmount += refund.Amount / 100m;
        payment.Status = payment.RefundedAmount >= payment.Amount ? "Refunded" : "PartiallyRefunded";
        payment.ReconciledAt = DateTime.UtcNow;
        await db.SaveChangesAsync(cancellationToken);
        return new PaymentResponse { Id = payment.Id, UserId = payment.UserId, PaymentType = payment.PaymentType, ReservationId = payment.ReservationId, MembershipId = payment.MembershipId, OrderId = payment.OrderId, Amount = payment.Amount, PaymentMethod = payment.PaymentMethod, Status = payment.Status, TransactionId = payment.TransactionId, PaymentDate = payment.PaymentDate, CreatedAt = payment.CreatedAt, Provider = payment.Provider, Currency = payment.Currency, RefundedAmount = payment.RefundedAmount, ReceiptUrl = payment.ReceiptUrl, ReconciledAt = payment.ReconciledAt };
    }

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
