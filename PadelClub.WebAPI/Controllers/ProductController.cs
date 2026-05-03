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
        [Authorize(Roles = "Administrator")]
        public override async Task<ActionResult<ProductResponse>> Create([FromBody] ProductInsertRequest request)
        {
            return await _crudService.CreateAsync(request);
        }

        [HttpPut("{id}/activate")]
        public async Task<ActionResult<ProductResponse?>> ActivateAsync(int id)
        {
            return await ActivateAsyncMethod(id);
        }

        [HttpPut("{id}/deactivate")]
        public async Task<ActionResult<ProductResponse?>> DeactivateAsync(int id)
        {
            return await DeactivateAsyncMethod(id);
        }
    }
}
