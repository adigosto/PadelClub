using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;
using PadelClub.Model.Responses;
using Microsoft.EntityFrameworkCore;
using PadelClub.Services.Database;

namespace PadelClub.WebAPI.Controllers
{
    public class MembershipsController : BaseCRUDController<MembershipResponse, MembershipSearchObject, MembershipInsertRequest, MembershipUpdateRequest>
    {
        private readonly PadelClubContext _db;
        private readonly INotificationService _notifications;

        public MembershipsController(IMembershipService service, PadelClubContext db, INotificationService notifications) : base(service)
        {
            _db = db;
            _notifications = notifications;
        }

        [HttpGet, Authorize(Policy = "AdminOnly")]
        public override Task<PagedResult<MembershipResponse>> Get([FromQuery] MembershipSearchObject? search) => base.Get(search);
        [HttpGet("{id:int}"), Authorize(Policy = "AdminOnly")]
        public override Task<MembershipResponse?> GetById(int id) => base.GetById(id);
        [HttpPost, Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<MembershipResponse>> Create([FromBody] MembershipInsertRequest request) => base.Create(request);
        [HttpPut("{id:int}"), Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<MembershipResponse?>> Update(int id, [FromBody] MembershipUpdateRequest request) => base.Update(id, request);
        [HttpDelete("{id:int}"), Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<bool>> Delete(int id) => base.Delete(id);

        [HttpGet("mine")]
        public Task<PagedResult<MembershipResponse>> Mine([FromQuery] MembershipSearchObject? search)
        {
            search ??= new MembershipSearchObject();
            search.UserId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
            return base.Get(search);
        }

        [HttpPut("{id:int}/cancel-at-period-end")]
        public async Task<IActionResult> CancelAtPeriodEnd(int id, CancellationToken ct)
        {
            var membership = await Owned(id, ct);
            if (membership is null) return NotFound();
            if (membership.Status is not ("Active" or "Suspended")) return Conflict("This membership cannot be cancelled.");
            membership.CancelAtPeriodEnd = true; membership.AutoRenew = false; membership.UpdatedAt = DateTime.UtcNow;
            membership.Events.Add(new MembershipEvent { EventType = "CancellationScheduled", Notes = "Cancellation requested for the end of the current period.", ActorUserId = membership.UserId });
            await _db.SaveChangesAsync(ct);
            return NoContent();
        }

        [HttpPut("{id:int}/auto-renew")]
        public async Task<IActionResult> AutoRenew(int id, [FromBody] AutoRenewRequest request, CancellationToken ct)
        {
            var membership = await Owned(id, ct);
            if (membership is null) return NotFound();
            if (membership.Status != "Active") return Conflict("Only active memberships can change automatic renewal.");
            membership.AutoRenew = request.Enabled; if (request.Enabled) membership.CancelAtPeriodEnd = false;
            membership.UpdatedAt = DateTime.UtcNow;
            membership.Events.Add(new MembershipEvent { EventType = "AutoRenewChanged", Notes = request.Enabled ? "Automatic renewal enabled." : "Automatic renewal disabled.", ActorUserId = membership.UserId });
            await _db.SaveChangesAsync(ct);
            return NoContent();
        }

        [HttpPut("{id:int}/status")]
        [Authorize(Policy = "AdminOnly")]
        public async Task<IActionResult> ChangeStatus(int id, [FromBody] MembershipStatusRequest request, CancellationToken ct)
        {
            var status = new[] { "Active", "Suspended", "Cancelled" }.FirstOrDefault(x => x.Equals(request.Status, StringComparison.OrdinalIgnoreCase));
            if (status is null) return BadRequest("Status must be Active, Suspended, or Cancelled.");
            var membership = await _db.Memberships.Include(x => x.Events).SingleOrDefaultAsync(x => x.Id == id, ct);
            if (membership is null) return NotFound();
            membership.Status = status; membership.IsActive = status == "Active"; membership.UpdatedAt = DateTime.UtcNow;
            membership.SuspendedAt = status == "Suspended" ? DateTime.UtcNow : null;
            membership.CancelledAt = status == "Cancelled" ? DateTime.UtcNow : null;
            if (status == "Cancelled") { membership.AutoRenew = false; membership.CancelAtPeriodEnd = false; }
            membership.Events.Add(new MembershipEvent { EventType = status, Notes = string.IsNullOrWhiteSpace(request.Notes) ? $"Membership changed to {status}." : request.Notes.Trim(), ActorUserId = CurrentUserId() });
            await _db.SaveChangesAsync(ct);
            await _notifications.CreateAsync(new NotificationInsertRequest { Title = $"Membership {status.ToLowerInvariant()}", Message = $"Your {membership.MembershipType} membership is now {status.ToLowerInvariant()}.", Type = "Memberships", RecipientUserIds = [membership.UserId] });
            return NoContent();
        }

        [HttpPost("{id:int}/renew")]
        [Authorize(Policy = "AdminOnly")]
        public async Task<IActionResult> Renew(int id, [FromBody] MembershipRenewRequest request, CancellationToken ct)
        {
            if (request.Months is < 1 or > 24) return BadRequest("Renewal must be between 1 and 24 months.");
            var membership = await _db.Memberships.Include(x => x.Events).SingleOrDefaultAsync(x => x.Id == id, ct);
            if (membership is null) return NotFound();
            var from = membership.EndDate > DateTime.UtcNow ? membership.EndDate : DateTime.UtcNow;
            membership.EndDate = from.AddMonths(request.Months); membership.Status = "Active"; membership.IsActive = true;
            membership.CancelAtPeriodEnd = false; membership.CancelledAt = null; membership.SuspendedAt = null; membership.UpdatedAt = DateTime.UtcNow;
            membership.Events.Add(new MembershipEvent { EventType = "Renewed", Notes = $"Membership renewed for {request.Months} month(s).", ActorUserId = CurrentUserId() });
            await _db.SaveChangesAsync(ct);
            return NoContent();
        }

        [HttpGet("{id:int}/history")]
        public async Task<ActionResult<object>> History(int id, CancellationToken ct)
        {
            var membership = await _db.Memberships.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id, ct);
            if (membership is null) return NotFound();
            if (!User.IsInRole("Administrator") && membership.UserId != CurrentUserId()) return Forbid();
            return Ok(await _db.MembershipEvents.AsNoTracking().Where(x => x.MembershipId == id).OrderByDescending(x => x.CreatedAt)
                .Select(x => new { x.Id, x.EventType, x.Notes, x.ActorUserId, x.CreatedAt }).ToListAsync(ct));
        }

        private int CurrentUserId() => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        private Task<Membership?> Owned(int id, CancellationToken ct) => _db.Memberships.Include(x => x.Events).SingleOrDefaultAsync(x => x.Id == id && x.UserId == CurrentUserId(), ct);
    }

    public sealed record AutoRenewRequest(bool Enabled);
    public sealed record MembershipStatusRequest(string Status, string Notes);
    public sealed record MembershipRenewRequest(int Months);
}
