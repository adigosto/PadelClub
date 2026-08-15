using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;

namespace PadelClub.WebAPI.Controllers
{
    
    public class CourtsController : BaseCRUDController<CourtResponse, CourtSearchObject, CourtInsertRequest, CourtUpdateRequest>
    {
        public CourtsController(ICourtService service) : base(service)
        {
        }

        [HttpPost]
        [Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<CourtResponse>> Create([FromBody] CourtInsertRequest request) => base.Create(request);

        [HttpPut("{id:int}")]
        [Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<CourtResponse?>> Update(int id, [FromBody] CourtUpdateRequest request) => base.Update(id, request);

        [HttpDelete("{id:int}")]
        [Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<bool>> Delete(int id) => base.Delete(id);
    }
        
}
