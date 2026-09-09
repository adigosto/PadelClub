using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using PadelClub.Services.Database;

namespace PadelClub.WebAPI.Payments;

public sealed record PayableResponse(int ReferenceId, string ReferenceType, string Description, decimal Amount, string Currency);
public sealed record PaymentStateResponse(int PaymentId, string Status, decimal Amount, string Currency);
public interface IMobilePaymentService
{
    Task<List<PayableResponse>> GetPayablesAsync(int userId, string type, int page, CancellationToken ct);
    Task<PaymentStateResponse?> GetStateAsync(int userId, int paymentId, CancellationToken ct);
}

public sealed class MobilePaymentService(PadelClubContext db, IOptions<StripeOptions> options) : IMobilePaymentService
{
    public async Task<List<PayableResponse>> GetPayablesAsync(int userId, string type, int page, CancellationToken ct)
    {
        if (page < 1 || page > 100000) throw new InvalidOperationException("Invalid page.");
        var currency = options.Value.Currency;
        IQueryable<PayableResponse> query = type switch
        {
            "Order" => db.Orders.AsNoTracking()
                .Where(x => x.UserId == userId && x.Status != "Cancelled" && x.TotalAmount > 0 &&
                    (x.Payment == null || x.Payment.Provider == "Stripe" && (x.Payment.Status == "Pending" || x.Payment.Status == "InitiationFailed" || x.Payment.Status == "Failed")))
                .OrderByDescending(x => x.Id).Select(x => new PayableResponse(x.Id, "Order", x.OrderNumber, x.TotalAmount, currency)),
            "Reservation" => db.Reservations.AsNoTracking()
                .Where(x => x.UserId == userId && x.Status == "Confirmed" && x.TotalPrice > 0 &&
                    (x.Payment == null || x.Payment.Provider == "Stripe" && (x.Payment.Status == "Pending" || x.Payment.Status == "InitiationFailed" || x.Payment.Status == "Failed")))
                .OrderByDescending(x => x.Id).Select(x => new PayableResponse(x.Id, "Reservation", x.Court.Name + " · " + x.StartTime.ToString(), x.TotalPrice, currency)),
            "Membership" => db.Memberships.AsNoTracking()
                .Where(x => x.UserId == userId && x.IsActive && x.Price > 0 &&
                    (x.Payment == null || x.Payment.Provider == "Stripe" && (x.Payment.Status == "Pending" || x.Payment.Status == "InitiationFailed" || x.Payment.Status == "Failed")))
                .OrderByDescending(x => x.Id).Select(x => new PayableResponse(x.Id, "Membership", x.MembershipType, x.Price, currency)),
            _ => throw new InvalidOperationException("Unknown payment type.")
        };
        return await query.Skip((page - 1) * 50).Take(50).ToListAsync(ct);
    }

    public Task<PaymentStateResponse?> GetStateAsync(int userId, int paymentId, CancellationToken ct) =>
        db.Payments.AsNoTracking().Where(x => x.Id == paymentId && x.UserId == userId)
            .Select(x => new PaymentStateResponse(x.Id, x.Status, x.Amount, x.Currency)).SingleOrDefaultAsync(ct);
}
