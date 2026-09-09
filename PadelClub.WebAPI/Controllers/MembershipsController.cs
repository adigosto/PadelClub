using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;
using PadelClub.Model.Responses;
using PadelClub.WebAPI.Memberships;

namespace PadelClub.WebAPI.Controllers
{
    public class MembershipsController : BaseCRUDController<MembershipResponse, MembershipSearchObject, MembershipInsertRequest, MembershipUpdateRequest>
    {
        private readonly IMembershipLifecycleService _lifecycle;
        private readonly INotificationService _notifications;

        public MembershipsController(IMembershipService service, IMembershipLifecycleService lifecycle, INotificationService notifications) : base(service)
        {
            _lifecycle = lifecycle;
            _notifications = notifications;
        }

        [HttpGet, Authorize(Policy = "AdminOnly")]
        public override Task<PagedResult<MembershipResponse>> Get([FromQuery] MembershipSearchObject? search) => base.Get(search);
        [HttpGet("{id:int}"), Authorize(Policy = "AdminOnly")]
        public override Task<MembershipResponse?> GetById(int id) => base.GetById(id);
        [HttpPost, Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<MembershipResponse>> Create([FromBody] MembershipInsertRequest request) => base.Create(request);
        [NonAction, Authorize(Policy = "AdminOnly")]
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

        [HttpGet("types"), Authorize(Policy = "AdminOnly")]
        public Task<List<MembershipTypeReferenceResponse>> Types(CancellationToken ct) =>
            ((IMembershipService)_crudService).GetTypeReferencesAsync(ct);

        [HttpPut("{id:int}/cancel-at-period-end")]
        public async Task<IActionResult> CancelAtPeriodEnd(int id, CancellationToken ct)
        {
            var membership = await _lifecycle.GetOwnedAsync(id, CurrentUserId(), ct);
            if (membership is null) return NotFound();
            if (membership.Status is not ("Active" or "Suspended")) return Conflict("This membership cannot be cancelled.");
            await _lifecycle.CancelAtPeriodEndAsync(membership, ct);
            return NoContent();
        }

        [HttpPut("{id:int}/auto-renew")]
        public async Task<IActionResult> AutoRenew(int id, [FromBody] AutoRenewRequest request, CancellationToken ct)
        {
            var membership = await _lifecycle.GetOwnedAsync(id, CurrentUserId(), ct);
            if (membership is null) return NotFound();
            if (membership.Status != "Active") return Conflict("Only active memberships can change automatic renewal.");
            await _lifecycle.SetAutoRenewAsync(membership, request.Enabled, ct);
            return NoContent();
        }

        [HttpPut("{id:int}/status")]
        [Authorize(Policy = "AdminOnly")]
        public async Task<IActionResult> ChangeStatus(int id, [FromBody] MembershipStatusRequest request, CancellationToken ct)
        {
            var status = new[] { "Active", "Suspended", "Cancelled" }.FirstOrDefault(x => x.Equals(request.Status, StringComparison.OrdinalIgnoreCase));
            if (status is null) return BadRequest("Status must be Active, Suspended, or Cancelled.");
            var membership = await _lifecycle.GetAsync(id, ct);
            if (membership is null) return NotFound();
            await _lifecycle.ChangeStatusAsync(membership, status, request.Notes, CurrentUserId(), ct);
            await _notifications.CreateAsync(new NotificationInsertRequest { Title = $"Membership {status.ToLowerInvariant()}", Message = $"Your {membership.MembershipType} membership is now {status.ToLowerInvariant()}.", Type = "Memberships", RecipientUserIds = [membership.UserId] });
            return NoContent();
        }

        [HttpPost("{id:int}/renew")]
        [Authorize(Policy = "AdminOnly")]
        public async Task<IActionResult> Renew(int id, [FromBody] MembershipRenewRequest request, CancellationToken ct)
        {
            if (request.Months is < 1 or > 24) return BadRequest("Renewal must be between 1 and 24 months.");
            var membership = await _lifecycle.GetAsync(id, ct);
            if (membership is null) return NotFound();
            await _lifecycle.RenewAsync(membership, request.Months, CurrentUserId(), ct);
            return NoContent();
        }

        [HttpGet("{id:int}/history")]
        public async Task<ActionResult<object>> History(int id, CancellationToken ct)
        {
            var membership = await _lifecycle.GetAsync(id, ct);
            if (membership is null) return NotFound();
            if (!User.IsInRole("Administrator") && membership.UserId != CurrentUserId()) return Forbid();
            return Ok(await _lifecycle.GetHistoryAsync(id, ct));
        }

        private int CurrentUserId() => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    }

    public sealed record AutoRenewRequest(bool Enabled);
    public sealed record MembershipStatusRequest(string Status, string Notes);
    public sealed record MembershipRenewRequest(int Months);
}
