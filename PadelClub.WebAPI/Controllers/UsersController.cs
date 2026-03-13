using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;

namespace PadelClub.WebAPI.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class UsersController : ControllerBase
    {
        protected readonly IUserService _service;

        public UsersController(IUserService service)
        {
            _service = service;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<UserResponse>>> Get([FromQuery] UserSearchObject? search)
        {
            var users = await _service.Get(search);
            return Ok(users);
        }

        [HttpGet("{id:int}")]
        public async Task<ActionResult<UserResponse>> GetById(int id)
        {
            var user = await _service.GetById(id);
            if (user == null) return NotFound();
            return Ok(user);
        }

        [HttpPost]
        public async Task<ActionResult<UserResponse>> Create(UserRequest request)
        {
            var userResponse = await _service.Create(request);
            return CreatedAtAction(nameof(GetById), new { id = userResponse.Id }, userResponse);
        }

        [HttpPut("{id:int}")]
        public async Task<ActionResult<UserResponse>> Update(int id, UserRequest request)
        {
            var userResponse = await _service.Update(id, request);
            if (userResponse == null) return NotFound();
            return Ok(userResponse);
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


