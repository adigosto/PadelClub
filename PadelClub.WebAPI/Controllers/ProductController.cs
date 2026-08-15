using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;

namespace PadelClub.WebAPI.Controllers
{
    public class ProductController : BaseCRUDController<ProductResponse, ProductSearchObject, ProductInsertRequest, ProductUpdateRequest>
    {
        public ProductController(IProductService service) : base(service)
        {
        }

        [HttpPost]
        [Authorize(Policy = "AdminOnly")]
        public override async Task<ActionResult<ProductResponse>> Create([FromBody] ProductInsertRequest request)
        {
            return await _crudService.CreateAsync(request);
        }

        [HttpPut("{id}/activate")]
        [Authorize(Policy = "AdminOnly")]
        public async Task<ActionResult<ProductResponse?>> ActivateAsync(int id)
        {
            return await ActivateAsyncMethod(id);
        }

        [HttpPut("{id}/deactivate")]
        [Authorize(Policy = "AdminOnly")]
        public async Task<ActionResult<ProductResponse?>> DeactivateAsync(int id)
        {
            return await DeactivateAsyncMethod(id);
        }

        [HttpPut("{id:int}"), Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<ProductResponse?>> Update(int id, [FromBody] ProductUpdateRequest request) => base.Update(id, request);

        [HttpDelete("{id:int}"), Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<bool>> Delete(int id) => base.Delete(id);
    }
}
