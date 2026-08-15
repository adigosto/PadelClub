using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;
using Microsoft.AspNetCore.Authorization;

namespace PadelClub.WebAPI.Controllers
{
    public class ProductCategoriesController : BaseCRUDController<ProductCategoryResponse, ProductCategorySearchObject, ProductCategoryInsertRequest, ProductCategoryUpdateRequest>
    {
        public ProductCategoriesController(IProductCategoryService service) : base(service)
        {
        }
        [HttpPost, Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<ProductCategoryResponse>> Create([FromBody] ProductCategoryInsertRequest request) => base.Create(request);
        [HttpPut("{id:int}"), Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<ProductCategoryResponse?>> Update(int id, [FromBody] ProductCategoryUpdateRequest request) => base.Update(id, request);
        [HttpDelete("{id:int}"), Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<bool>> Delete(int id) => base.Delete(id);
    }
}
