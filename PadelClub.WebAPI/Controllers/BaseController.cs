using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;
using PadelClub.Services.IService;

namespace PadelClub.WebAPI.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class BaseController<T, TSearch> : ControllerBase where T : class where TSearch : class, new() 
    {
        protected readonly IService<T, TSearch> _service;
        public BaseController(IService<T, TSearch> service)
        {
            _service = service;
        }
        [HttpGet("")]
        public async Task<IEnumerable<T>> Get([FromQuery]TSearch? search)
        {
            return await _service.GetAsync(search ?? new TSearch());
        }   

        [HttpGet("{id}")]
        public async Task<T?> GetById(int id)
        {
            return await _service.GetByIdAsync(id);
        }
    }
}
