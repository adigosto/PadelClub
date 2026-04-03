using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;

namespace PadelClub.WebAPI.Controllers
{
    public class ProductCategoriesController : BaseCRUDController<ProductCategoryResponse, ProductCategorySearchObject, ProductCategoryInsertRequest, ProductCategoryUpdateRequest>
    {
        public ProductCategoriesController(IProductCategoryService service) : base(service)
        {
        }
    }
}
