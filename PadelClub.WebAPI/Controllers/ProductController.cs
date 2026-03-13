using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;

namespace PadelClub.WebAPI.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class ProductController : ControllerBase
    {
        protected readonly IProductService _service;
        public ProductController(IProductService service)
        {
            _service = service;
        }
        [HttpGet()]
        public IEnumerable<Product> Get([FromQuery]ProductSearchObject? search)
        {
            return _service.Get(search);
        }

        [HttpGet("{id}")]
        public Product Get(int id)
        {
            return _service.Get(id);
        }
    }
}
