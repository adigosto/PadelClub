using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;
using PadelClub.WebAPI.Authentication;

namespace PadelClub.WebAPI.Controllers
{

    public class ReservationsController : BaseCRUDController<ReservationResponse, ReservationSearchObject, ReservationInsertRequest, ReservationUpdateRequest>
    {
        private readonly ICurrentUser _currentUser;

        public ReservationsController(IReservationService service, ICurrentUser currentUser) : base(service)
        {
            _currentUser = currentUser;
        }

        [HttpGet]
        [Authorize(Policy = "AdminOnly")]
        public override Task<PadelClub.Model.Responses.PagedResult<ReservationResponse>> Get([FromQuery] ReservationSearchObject? search) => base.Get(search);

        [HttpGet("{id:int}")]
        public override async Task<ReservationResponse?> GetById(int id)
        {
            var result = await ((IReservationService)_crudService).GetOwnedByIdAsync(id, _currentUser.Id, _currentUser.IsAdministrator);
            return result ?? throw new KeyNotFoundException("Reservation was not found.");
        }

        [HttpGet("availability")]
        public async Task<ActionResult> GetAvailability([FromQuery] DateTime date)
        {
            return Ok(await ((IReservationService)_crudService).GetAvailabilityAsync(date));
        }

        [HttpGet("mine")]
        public async Task<ActionResult> GetMine([FromQuery] ReservationSearchObject? search)
        {
            return Ok(await ((IReservationService)_crudService).GetForUserAsync(_currentUser.Id, search ?? new ReservationSearchObject()));
        }

        [HttpPost]
        public override Task<ActionResult<ReservationResponse>> Create([FromBody] ReservationInsertRequest request)
        {
            request.UserId = _currentUser.Id;
            request.Status = "Confirmed";
            request.TotalPrice = 0;
            return base.Create(request);
        }

        [HttpPut("{id:int}")]
        [Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<ReservationResponse?>> Update(int id, [FromBody] ReservationUpdateRequest request) => base.Update(id, request);

        [HttpDelete("{id:int}")]
        [Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<bool>> Delete(int id) => base.Delete(id);

        [HttpPut("{id:int}/cancel")]
        public async Task<ActionResult> Cancel(int id, [FromBody] CancelReservationRequest request)
        {
            try
            {
                var isAdministrator = User.IsInRole("Administrator");
                var result = await ((IReservationService)_crudService).CancelAsync(id, _currentUser.Id, isAdministrator, request.Reason);
                return result == null ? NotFound() : Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return Conflict(ex.Message);
            }
        }

        [HttpPost("recurring")]
        public Task<List<ReservationResponse>> CreateRecurring([FromBody] RecurringReservationRequest request) => ((IReservationService)_crudService).CreateRecurringAsync(_currentUser.Id, request);

        [HttpPost("waitlist")]
        public Task<PadelClub.Model.Responses.WaitlistEntryResponse> JoinWaitlist([FromBody] WaitlistRequest request) => ((IReservationService)_crudService).JoinWaitlistAsync(_currentUser.Id, request);

        [HttpGet("waitlist/mine")]
        public Task<List<PadelClub.Model.Responses.WaitlistEntryResponse>> WaitlistMine([FromQuery] int page = 1, [FromQuery] int pageSize = 50) => ((IReservationService)_crudService).GetWaitlistAsync(_currentUser.Id, page, pageSize);

        [HttpGet("credits/mine")]
        public Task<List<PadelClub.Model.Responses.AccountCreditResponse>> CreditsMine([FromQuery] int page = 1, [FromQuery] int pageSize = 50) => ((IReservationService)_crudService).GetCreditsAsync(_currentUser.Id, page, pageSize);

        [HttpPost("maintenance"), Authorize(Policy = "AdminOnly")]
        public async Task<ActionResult<int>> AddMaintenance([FromBody] MaintenanceBlockRequest request) => Ok(await ((IReservationService)_crudService).AddMaintenanceBlockAsync(request));

        [HttpPut("{id:int}/no-show"), Authorize(Policy = "AdminOnly")]
        public async Task<IActionResult> MarkNoShow(int id) => await ((IReservationService)_crudService).MarkNoShowAsync(id, _currentUser.Id) ? NoContent() : NotFound();

    }
}

