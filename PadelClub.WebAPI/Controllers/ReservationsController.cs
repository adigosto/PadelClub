using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;

namespace PadelClub.WebAPI.Controllers
{

    public class ReservationsController : BaseCRUDController<ReservationResponse, ReservationSearchObject, ReservationRequest, ReservationRequest>
    {
        public ReservationsController(IReservationService service) : base(service)
        {
        }


        // [HttpPost]
        // public async Task<ActionResult<ReservationResponse>> Create(ReservationRequest request)
        // {
        //     var reservationResponse = await _service.Create(request);
        //     return CreatedAtAction(nameof(GetById), new { id = reservationResponse.Id }, reservationResponse);
        // }

        // [HttpPut("{id:int}")]
        // public async Task<ActionResult<ReservationResponse>> Update(int id, ReservationRequest request)
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

