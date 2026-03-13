using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;

namespace PadelClub.WebAPI.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class CourtsController : ControllerBase
    {
        protected readonly ICourtService _service;

        public CourtsController(ICourtService service)
        {
            _service = service;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<CourtResponse>>> Get([FromQuery] CourtSearchObject? search)
        {
            var courts = await _service.Get(search);
            return Ok(courts);
        }

        [HttpGet("{id:int}")]
        public async Task<ActionResult<CourtResponse>> GetById(int id)
        {
            var court = await _service.GetById(id);
            if (court == null) return NotFound();
            return Ok(court);
        }

        [HttpPost]
        public async Task<ActionResult<CourtResponse>> Create(CourtRequest request)
        {
            var courtResponse = await _service.Create(request);
            return CreatedAtAction(nameof(GetById), new { id = courtResponse.Id }, courtResponse);
        }

        [HttpPut("{id:int}")]
        public async Task<ActionResult<CourtResponse>> Update(int id, CourtRequest request)
        {
            var courtResponse = await _service.Update(id, request);
            if (courtResponse == null) return NotFound();
            return Ok(courtResponse);
        }

        [HttpDelete("{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            var deleted = await _service.Delete(id);
            if (!deleted) return NotFound();
            return NoContent();
        }
    }
}

