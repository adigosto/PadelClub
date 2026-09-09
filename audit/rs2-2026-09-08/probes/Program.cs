using System.Security.Claims;
using System.Text.Json;
using Mapster;
using MapsterMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Options;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;
using PadelClub.Services.Database;
using PadelClub.WebAPI.Controllers;
using PadelClub.WebAPI.Payments;
using PadelClub.WebAPI.Tournaments;
using Stripe;
using Payment = PadelClub.Services.Database.Payment;

// Local review probes: invoke actual application methods against an isolated
// in-memory database. They do not exercise HTTP middleware, SQL locking, Stripe,
// or external delivery. A reproduced=true result confirms existing bad behavior.
var options = new DbContextOptionsBuilder<PadelClubContext>()
    .UseInMemoryDatabase(Guid.NewGuid().ToString())
    .ConfigureWarnings(w => w.Ignore(InMemoryEventId.TransactionIgnoredWarning)).Options;
await using var db = new PadelClubContext(options);
var mapper = new Mapper(new TypeAdapterConfig());
var notifications = new NotificationService(db, mapper);
var reservations = new ReservationService(db, mapper, notifications, Options.Create(new BookingOptions()));
var results = new List<object>();
void Record(string id, bool reproduced, object evidence) => results.Add(new { id, reproduced, evidence });

var start = DateTime.SpecifyKind(DateTime.UtcNow.Date.AddDays(5).AddHours(10), DateTimeKind.Utc);
db.Users.AddRange(new PadelClub.Services.Database.User { Id = 1, Username = "owner", Email = "owner@example.invalid", FirstName = "Owner", LastName = "One", PasswordHash = "unused", PasswordSalt = "unused" },
    new PadelClub.Services.Database.User { Id = 2, Username = "other", Email = "other@example.invalid", FirstName = "Other", LastName = "Two", PasswordHash = "unused", PasswordSalt = "unused" });
db.Courts.Add(new Court { Id = 1, Name = "Audit court", IsActive = true, HourlyRate = 30 });
db.Reservations.AddRange(Enumerable.Range(1, 15).Select(i => new Reservation { Id = i, UserId = 1, CourtId = 1, Status = "Confirmed", StartTime = start.AddDays(i), EndTime = start.AddDays(i).AddHours(1), TotalPrice = 30, Notes = "Owner private note" }));
await db.SaveChangesAsync();

var controller = new ReservationsController(reservations) { ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, "2")], "audit")) } } };
var leaked = await controller.GetById(1);
var method = typeof(ReservationsController).GetMethod("GetById")!;
Record("IDOR", leaked?.UserId == 1, new { caller = 2, owner = leaked?.UserId, leaked?.Notes, inheritedFrom = method.DeclaringType?.Name, methodPolicies = method.GetCustomAttributes(typeof(AuthorizeAttribute), true).Cast<AuthorizeAttribute>().Select(a => a.Policy).ToArray() });

var unlimited = await reservations.GetAsync(new ReservationSearchObject { PageSize = 0 });
Record("PAGINATION", unlimited.Items.Count == 15, new { requestedPageSize = 0, returned = unlimited.Items.Count });

await reservations.UpdateAsync(1, new ReservationUpdateRequest { CourtId = 1, UserId = 1, StartTime = start, EndTime = start.AddHours(1), Status = "ArbitraryState" });
Record("STATE", (await db.Reservations.FindAsync(1))!.Status == "ArbitraryState", new { acceptedStatus = (await db.Reservations.FindAsync(1))!.Status });

await reservations.MarkNoShowAsync(2);
Record("FUTURE_NO_SHOW", (await db.Reservations.FindAsync(2))!.Status == "NoShow", new { scheduled = (await db.Reservations.FindAsync(2))!.StartTime, now = DateTime.UtcNow });
await reservations.DeleteAsync(3);
Record("HARD_DELETE", !await db.Reservations.AnyAsync(r => r.Id == 3), new { deletedPreviouslyConfirmedReservation = 3 });

db.Payments.Add(new Payment { Id = 1, UserId = 1, ReservationId = 4, Amount = 30, Status = "Completed", Provider = "Stripe", PaymentType = "Reservation", PaymentMethod = "Stripe", TransactionId = "pi_audit" });
await db.SaveChangesAsync();
await reservations.CancelAsync(4, 1, false);
Record("CREDIT_PAYMENT_LEDGER", await db.AccountCredits.AnyAsync(c => c.ReservationId == 4) && (await db.Payments.FindAsync(1))!.Status == "Completed", new { creditAmount = await db.AccountCredits.Where(c => c.ReservationId == 4).SumAsync(c => c.Amount), paymentStillRefundable = (await db.Payments.FindAsync(1))!.Status });

var payments = new PaymentService(db, mapper, notifications);
await payments.UpdateAsync(1, new PaymentUpdateRequest { UserId = 1, ReservationId = 4, Amount = 999, PaymentType = "Reservation", PaymentMethod = "Stripe", Status = "Completed", TransactionId = "pi_audit" });
Record("MANUAL_SETTLEMENT", (await db.Payments.FindAsync(1))!.Amount == 999, new { acceptedAmount = (await db.Payments.FindAsync(1))!.Amount, status = (await db.Payments.FindAsync(1))!.Status });

var stripe = new StripePaymentService(db, Options.Create(new StripeOptions()));
Event IntentEvent(string eventId, string intentId, string status) => new() { Id = eventId, Type = "payment_intent." + status, Data = new Stripe.EventData { Object = new PaymentIntent { Id = intentId, Status = status } } };
await stripe.ProcessWebhookAsync(IntentEvent("evt_success", "pi_audit", "succeeded"), default);
await stripe.ProcessWebhookAsync(IntentEvent("evt_older", "pi_audit", "processing"), default);
Record("WEBHOOK_REGRESSION", (await db.Payments.FindAsync(1))!.Status == "Pending", new { afterSuccessThenOlderEvent = (await db.Payments.FindAsync(1))!.Status });

await stripe.ProcessWebhookAsync(IntentEvent("evt_early", "pi_linked_later", "succeeded"), default);
db.Payments.Add(new Payment { Id = 2, UserId = 1, Amount = 30, Status = "Pending", Provider = "Stripe", PaymentType = "Order", PaymentMethod = "Stripe", TransactionId = "pi_linked_later" });
await db.SaveChangesAsync();
await stripe.ProcessWebhookAsync(IntentEvent("evt_early", "pi_linked_later", "succeeded"), default);
Record("EARLY_WEBHOOK_LOST", (await db.Payments.FindAsync(2))!.Status == "Pending", new { afterMatchingPaymentAndReplay = (await db.Payments.FindAsync(2))!.Status, eventRecorded = await db.StripeWebhookEvents.AnyAsync(e => e.StripeEventId == "evt_early") });

db.Tournaments.Add(new Tournament { Id = 1, Name = "Audit tournament", Description = "Local probe", StartDate = start, EndDate = start.AddDays(1), RegistrationDeadline = start.AddDays(-1), Status = "Upcoming" });
db.TournamentParticipants.AddRange(new TournamentParticipant { TournamentId = 1, UserId = 1, Status = "Confirmed", TeamNumber = null }, new TournamentParticipant { TournamentId = 1, UserId = 2, Status = "Confirmed", TeamNumber = null });
await db.SaveChangesAsync();
var brackets = new BracketService(db);
var tournamentController = new TournamentLifecycleController(db, brackets, notifications) { ControllerContext = controller.ControllerContext };
await tournamentController.Withdraw(1, default);
Record("NULL_TEAM_WITHDRAWAL", await db.TournamentParticipants.AllAsync(p => p.Status == "Withdrawn"), new { caller = 2, unrelatedOwnerStatus = (await db.TournamentParticipants.SingleAsync(p => p.UserId == 1)).Status });

db.Users.Add(new PadelClub.Services.Database.User { Id = 3, Username = "opponent", Email = "opponent@example.invalid", FirstName = "Opponent", LastName = "Three", PasswordHash = "unused", PasswordSalt = "unused" });
db.Matches.Add(new PadelClub.Services.Database.Match { Id = 1, TournamentId = 1, CourtId = 1, ScheduledTime = start, Status = "Scheduled", ResultStatus = "PendingConfirmation", ReportedByUserId = 1, ProposedScore = "6-0, 6-0", ProposedWinnerTeamId = 1, Participants = [new MatchParticipant { UserId = 1, TeamNumber = 1 }, new MatchParticipant { UserId = 2, TeamNumber = 1 }, new MatchParticipant { UserId = 3, TeamNumber = 2 }] });
await db.SaveChangesAsync();
var experience = new PlayerExperienceController(db, notifications, brackets) { ControllerContext = controller.ControllerContext };
await experience.ConfirmResult(1, default);
Record("TEAMMATE_CONFIRMS", (await db.Matches.FindAsync(1))!.ResultStatus == "Confirmed", new { reporter = 1, confirmer = 2, bothOnTeam = 1, opponent = 3, resultingStatus = (await db.Matches.FindAsync(1))!.ResultStatus });

Console.WriteLine(JsonSerializer.Serialize(results, new JsonSerializerOptions { WriteIndented = true }));
return results.Count == 11 ? 0 : 1;
