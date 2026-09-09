using System.Text.Json;
using Mapster;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Options;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;
using PadelClub.Services.Database;
using PadelClub.Services.Recommendations;
using PadelClub.WebAPI.Payments;
using Stripe;
using Payment = PadelClub.Services.Database.Payment;

// Direct calls to real services in an isolated InMemory store: no HTTP, SQL locks or provider calls.
var options = new DbContextOptionsBuilder<PadelClubContext>()
    .UseInMemoryDatabase(Guid.NewGuid().ToString())
    .ConfigureWarnings(w => w.Ignore(InMemoryEventId.TransactionIgnoredWarning)).Options;
await using var db = new PadelClubContext(options);
var mapper = new Mapper(new TypeAdapterConfig());
var notifications = new NotificationService(db, mapper);
var reservations = new ReservationService(db, mapper, notifications, Options.Create(new BookingOptions()));
var results = new List<object>();
void Record(string id, bool observed, object evidence) => results.Add(new { id, observed, evidence });
var start = DateTime.SpecifyKind(DateTime.UtcNow.Date.AddDays(7).AddHours(10), DateTimeKind.Utc);
db.Users.Add(new PadelClub.Services.Database.User { Id = 1, Username = "audit", Email = "audit@example.invalid", FirstName = "Audit", LastName = "User", PasswordHash = "unused", PasswordSalt = "unused" });
db.Courts.Add(new Court { Id = 1, Name = "Audit", HourlyRate = 30, IsActive = true });
db.Reservations.Add(new Reservation { Id = 1, UserId = 1, CourtId = 1, Status = "Confirmed", StartTime = start, EndTime = start.AddHours(1), TotalPrice = 30 });
db.Payments.Add(new Payment { Id = 1, UserId = 1, ReservationId = 1, Amount = 30, Status = "Completed", Provider = "Stripe", PaymentType = "Reservation", PaymentMethod = "Stripe", TransactionId = "pi_credit_audit" });
await db.SaveChangesAsync();
Record("OWNERSHIP_FIXED", await reservations.GetOwnedByIdAsync(1, 2, false) is null, new { caller = 2, owner = 1 });
await reservations.CancelAsync(1, 1, false, "Schedule changed");
ProviderRefundOperation? refund = null;
string? refundRejection = null;
try
{
    refund = await new ProviderRefundOperationService(db).QueueDirectAsync(1, 1,
        new StripeRefundRequest { IdempotencyKey = "audit-credit-refund", Reason = "requested_by_customer" }, default);
}
catch (InvalidOperationException ex)
{
    refundRejection = ex.Message;
}
var credit = await db.AccountCredits.SumAsync(x => x.Amount);
Record("CREDIT_AND_REFUND", refund is null && credit == 30, new { charged = 30, credit, refundRejected = refundRejection });

db.Payments.Add(new Payment { Id = 2, UserId = 1, Amount = 30, Status = "Completed", Provider = "Stripe", PaymentType = "Order", PaymentMethod = "Stripe", TransactionId = "pi_charge_audit" });
await db.SaveChangesAsync();
var stripe = new StripePaymentService(db, Options.Create(new StripeOptions()));
Event ChargeEvent(string eventId, long refunded) => new() { Id = eventId, Type = "charge.refunded", Data = new Stripe.EventData { Object = new Charge { Id = "ch_audit", PaymentIntentId = "pi_charge_audit", AmountRefunded = refunded } } };
await stripe.ProcessWebhookAsync(ChargeEvent("evt_full_refund", 3000), default);
await stripe.ProcessWebhookAsync(ChargeEvent("evt_old_partial_refund", 1000), default);
var regressed = await db.Payments.FindAsync(2);
Record("REFUND_REGRESSION", regressed!.RefundedAmount == 30 && regressed.Status == "Refunded", new { originallyRefunded = 30, afterOlderEvent = regressed.RefundedAmount, regressed.Status });

db.Notifications.AddRange(Enumerable.Range(1, 120).Select(i => new Notification { Title = $"Audit {i}", Message = "Probe", Type = "Bookings" }));
await db.SaveChangesAsync();
var unlimited = await notifications.GetAsync(new NotificationSearchObject { PageSize = 0 });
Record("NOTIFICATIONS_UNBOUNDED", unlimited.Items.Count <= 100, new { requested = 0, returned = unlimited.Items.Count });

var order = new Order { UserId = 1, OrderNumber = "AUDIT", Status = "Delivered", TotalAmount = 999, ShippingAddress = "Audit address" };
db.Orders.Add(order);
await db.SaveChangesAsync();
Record("ORDER_CRUD_BYPASS", false, new { order.Status, order.TotalAmount, lines = await db.OrderItems.CountAsync(x => x.OrderId == order.Id) });

db.Memberships.Add(new Membership { Id = 1, UserId = 1, MembershipType = "Monthly", StartDate = start, EndDate = start.AddMonths(1), Price = 50, IsActive = true, Status = "Active" });
await db.SaveChangesAsync();
string? membershipUpdateRejection = null;
try
{
    await new MembershipService(db, mapper).UpdateAsync(1, new MembershipUpdateRequest { UserId = 1, MembershipType = "Monthly", StartDate = start, EndDate = start.AddDays(-1), Price = -25, IsActive = false });
}
catch (InvalidOperationException ex)
{
    membershipUpdateRejection = ex.Message;
}
var membership = await db.Memberships.FindAsync(1) ?? throw new InvalidOperationException("Membership probe row was not found.");
Record("MEMBERSHIP_UPDATE_BYPASS", membershipUpdateRejection is not null && membership!.Price == 50 && membership.EndDate > membership.StartDate, new { membership.Price, membership.StartDate, membership.EndDate, membership.Status, membership.IsActive, membershipUpdateRejection });
Console.WriteLine(JsonSerializer.Serialize(results, new JsonSerializerOptions { WriteIndented = true }));
if (results.Count != 6) throw new InvalidOperationException("Incomplete probes.");
