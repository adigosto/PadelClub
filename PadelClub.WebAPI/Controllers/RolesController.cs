using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;

namespace PadelClub.WebAPI.Controllers
{
    [Authorize(Policy = "AdminOnly")]
    public class RolesController : BaseCRUDController<RoleResponse, RoleSearchObject, RoleInsertRequest, RoleUpdateRequest>
    {
        public RolesController(IRoleService service) : base(service)
        {
        }

        [HttpGet]
        public override async Task<PagedResult<RoleResponse>> Get([FromQuery] RoleSearchObject? search)
        {
            return await _service.GetAsync(search ?? new RoleSearchObject());
        }

        [HttpGet("{id}")]
        public override async Task<RoleResponse?> GetById(int id)
        {
            return await _service.GetByIdAsync(id);
        }
    }
}
