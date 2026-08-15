using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PadelClub.Services.Database;

namespace PadelClub.WebAPI.Controllers;

[ApiController]
[Route("Privacy")]
[Authorize]
public sealed class PrivacyController(PadelClubContext db) : ControllerBase
{
    [HttpGet("export")]
    public async Task<ActionResult<object>> Export(CancellationToken ct)
    {
        var id = CurrentUserId();
        var user = await db.Users.AsNoTracking().Where(x => x.Id == id).Select(x => new { x.Id, x.Username, x.Email, x.FirstName, x.LastName, x.PhoneNumber, x.CreatedAt, x.UpdatedAt, x.EmailVerifiedAt }).SingleAsync(ct);
        var profile = await db.PlayerProfiles.AsNoTracking().Where(x => x.UserId == id).Select(x => new { x.SkillLevel, x.PreferredSide, x.City, x.Bio, x.Availability, x.IsDiscoverable, x.Rating, x.UpdatedAt }).SingleOrDefaultAsync(ct);
        var reservations = await db.Reservations.AsNoTracking().Where(x => x.UserId == id).Select(x => new { x.Id, x.CourtId, x.StartTime, x.EndTime, x.Status, x.TotalPrice, x.CreatedAt, x.CancelledAt }).ToListAsync(ct);
        var orders = await db.Orders.AsNoTracking().Where(x => x.UserId == id).Select(x => new { x.Id, x.OrderNumber, x.TotalAmount, x.DiscountAmount, x.Status, x.CreatedAt, x.DeliveredAt }).ToListAsync(ct);
        var memberships = await db.Memberships.AsNoTracking().Where(x => x.UserId == id).Select(x => new { x.Id, x.MembershipType, x.StartDate, x.EndDate, x.Price, x.Status, x.AutoRenew, x.CancelAtPeriodEnd }).ToListAsync(ct);
        var payments = await db.Payments.AsNoTracking().Where(x => x.UserId == id).Select(x => new { x.Id, x.PaymentType, x.Amount, x.Currency, x.Status, x.RefundedAmount, x.PaymentDate, x.ReceiptUrl }).ToListAsync(ct);
        var notifications = await db.NotificationRecipients.AsNoTracking().Where(x => x.UserId == id).Select(x => new { x.NotificationId, x.Notification.Title, x.Notification.Message, x.Notification.Type, x.Notification.CreatedAt, x.IsRead, x.ReadAt }).ToListAsync(ct);
        return Ok(new { ExportedAt = DateTime.UtcNow, User = user, PlayerProfile = profile, Reservations = reservations, Orders = orders, Memberships = memberships, Payments = payments, Notifications = notifications });
    }

    [HttpPost("deletion")]
    public async Task<ActionResult<object>> RequestDeletion(CancellationToken ct)
    {
        var userId = CurrentUserId();
        var existing = await db.PrivacyRequests.SingleOrDefaultAsync(x => x.UserId == userId && x.Status == "Scheduled", ct);
        if (existing is not null) return Conflict("Account deletion is already scheduled.");
        var request = new PrivacyRequest { UserId = userId, ScheduledFor = DateTime.UtcNow.AddDays(30) };
        db.PrivacyRequests.Add(request); await db.SaveChangesAsync(ct);
        return Ok(new { request.Id, request.Status, request.RequestedAt, request.ScheduledFor });
    }

    [HttpDelete("deletion")]
    public async Task<IActionResult> CancelDeletion(CancellationToken ct)
    {
        var request = await db.PrivacyRequests.SingleOrDefaultAsync(x => x.UserId == CurrentUserId() && x.Status == "Scheduled", ct);
        if (request is null) return NotFound();
        request.Status = "Cancelled"; request.CancelledAt = DateTime.UtcNow; await db.SaveChangesAsync(ct); return NoContent();
    }

    [HttpGet("deletion")]
    public async Task<ActionResult<object>> DeletionStatus(CancellationToken ct)
    {
        var request = await db.PrivacyRequests.AsNoTracking().Where(x => x.UserId == CurrentUserId()).OrderByDescending(x => x.RequestedAt)
            .Select(x => new { x.Id, x.Status, x.RequestedAt, x.ScheduledFor, x.CompletedAt, x.CancelledAt }).FirstOrDefaultAsync(ct);
        return request is null ? NoContent() : Ok(request);
    }

    private int CurrentUserId() => int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : throw new UnauthorizedAccessException();
}
