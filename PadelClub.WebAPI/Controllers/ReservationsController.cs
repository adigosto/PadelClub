using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;

namespace PadelClub.WebAPI.Controllers
{

    public class ReservationsController : BaseCRUDController<ReservationResponse, ReservationSearchObject, ReservationInsertRequest, ReservationUpdateRequest>
    {
        public ReservationsController(IReservationService service) : base(service)
        {
        }

        [HttpGet]
        [Authorize(Policy = "AdminOnly")]
        public override Task<PadelClub.Model.Responses.PagedResult<ReservationResponse>> Get([FromQuery] ReservationSearchObject? search) => base.Get(search);

        [HttpGet("availability")]
        public async Task<ActionResult> GetAvailability([FromQuery] DateTime date)
        {
            return Ok(await ((IReservationService)_crudService).GetAvailabilityAsync(date));
        }

        [HttpGet("mine")]
        public async Task<ActionResult> GetMine([FromQuery] ReservationSearchObject? search)
        {
            return Ok(await ((IReservationService)_crudService).GetForUserAsync(GetUserId(), search ?? new ReservationSearchObject()));
        }

        [HttpPost]
        public override Task<ActionResult<ReservationResponse>> Create([FromBody] ReservationInsertRequest request)
        {
            request.UserId = GetUserId();
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
        public async Task<ActionResult> Cancel(int id)
        {
            try
            {
                var isAdministrator = User.IsInRole("Administrator");
                var result = await ((IReservationService)_crudService).CancelAsync(id, GetUserId(), isAdministrator);
                return result == null ? NotFound() : Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return Conflict(ex.Message);
            }
        }

        [HttpPost("recurring")]
        public Task<List<ReservationResponse>> CreateRecurring([FromBody] RecurringReservationRequest request) => ((IReservationService)_crudService).CreateRecurringAsync(GetUserId(), request);

        [HttpPost("waitlist")]
        public Task<PadelClub.Model.Responses.WaitlistEntryResponse> JoinWaitlist([FromBody] WaitlistRequest request) => ((IReservationService)_crudService).JoinWaitlistAsync(GetUserId(), request);

        [HttpGet("waitlist/mine")]
        public Task<List<PadelClub.Model.Responses.WaitlistEntryResponse>> WaitlistMine() => ((IReservationService)_crudService).GetWaitlistAsync(GetUserId());

        [HttpGet("credits/mine")]
        public Task<List<PadelClub.Model.Responses.AccountCreditResponse>> CreditsMine() => ((IReservationService)_crudService).GetCreditsAsync(GetUserId());

        [HttpPost("maintenance"), Authorize(Policy = "AdminOnly")]
        public async Task<ActionResult<int>> AddMaintenance([FromBody] MaintenanceBlockRequest request) => Ok(await ((IReservationService)_crudService).AddMaintenanceBlockAsync(request));

        [HttpPut("{id:int}/no-show"), Authorize(Policy = "AdminOnly")]
        public async Task<IActionResult> MarkNoShow(int id) => await ((IReservationService)_crudService).MarkNoShowAsync(id) ? NoContent() : NotFound();

        private int GetUserId()
        {
            var value = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (!int.TryParse(value, out var userId))
                throw new UnauthorizedAccessException("The authenticated user identifier is invalid.");
            return userId;
        }


        // [HttpPost]
        // public async Task<ActionResult<ReservationResponse>> Create(ReservationInsertRequest request)
        // {
        //     var reservationResponse = await _service.Create(request);
        //     return CreatedAtAction(nameof(GetById), new { id = reservationResponse.Id }, reservationResponse);
        // }

        // [HttpPut("{id:int}")]
        // public async Task<ActionResult<ReservationResponse>> Update(int id, ReservationUpdateRequest request)
        // {
        //     var reservationResponse = await _service.Update(id, request);
        //     if (reservationResponse == null) return NotFound();
        //     return Ok(reservationResponse);
        // }

        // [HttpDelete("{id:int}")]
        // public async Task<IActionResult> Delete(int id)
        // {
        //     var deleted = await _service.Delete(id);
        //     if (!deleted) return NotFound();
        //     return NoContent();
        // }
    }
}

