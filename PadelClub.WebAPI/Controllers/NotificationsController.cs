using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;
using System.Security.Claims;

namespace PadelClub.WebAPI.Controllers
{
    [Authorize]
    public class NotificationsController : BaseCRUDController<NotificationResponse, NotificationSearchObject, NotificationInsertRequest, NotificationUpdateRequest>
    {
        private readonly INotificationService _notificationService;

        public NotificationsController(INotificationService service) : base(service)
        {
            _notificationService = service;
        }

        [HttpGet]
        [Authorize(Policy = "AdminOnly")]
        public override Task<PagedResult<NotificationResponse>> Get([FromQuery] NotificationSearchObject? search)
            => base.Get(search);

        [HttpGet("{id:int}")]
        [Authorize(Policy = "AdminOnly")]
        public override Task<NotificationResponse?> GetById(int id) => base.GetById(id);

        [HttpPost]
        [Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<NotificationResponse>> Create([FromBody] NotificationInsertRequest request)
            => base.Create(request);

        [HttpPut("{id:int}")]
        [Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<NotificationResponse?>> Update(int id, [FromBody] NotificationUpdateRequest request)
            => base.Update(id, request);

        [HttpDelete("{id:int}")]
        [Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<bool>> Delete(int id) => base.Delete(id);

        [HttpGet("mine")]
        public Task<PagedResult<NotificationResponse>> Mine([FromQuery] NotificationSearchObject? search)
            => _notificationService.GetForUserAsync(CurrentUserId(), search ?? new NotificationSearchObject());

        [HttpPut("{id:int}/read")]
        public async Task<ActionResult<NotificationResponse>> MarkRead(int id)
        {
            var result = await _notificationService.MarkReadAsync(id, CurrentUserId());
            return result == null ? NotFound() : Ok(result);
        }

        [HttpPut("read-all")]
        public async Task<ActionResult<int>> MarkAllRead()
        {
            return Ok(await _notificationService.MarkAllReadAsync(CurrentUserId()));
        }

        private int CurrentUserId()
        {
            var value = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (!int.TryParse(value, out var userId))
                throw new UnauthorizedAccessException("The authenticated user identifier is invalid.");
            return userId;
        }
    }
}
