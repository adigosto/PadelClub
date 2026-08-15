using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;
using Microsoft.AspNetCore.Authorization;

namespace PadelClub.WebAPI.Controllers
{
    public class ProductTypesController : BaseCRUDController<ProductTypeResponse, ProductTypeSearchObject, ProductTypeInsertRequest, ProductTypeUpdateRequest>
    {
        public ProductTypesController(IProductTypeService service) : base(service)
        {
        }
        [HttpPost, Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<ProductTypeResponse>> Create([FromBody] ProductTypeInsertRequest request) => base.Create(request);
        [HttpPut("{id:int}"), Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<ProductTypeResponse?>> Update(int id, [FromBody] ProductTypeUpdateRequest request) => base.Update(id, request);
        [HttpDelete("{id:int}"), Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<bool>> Delete(int id) => base.Delete(id);
    }
}
