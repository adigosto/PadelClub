using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;

namespace PadelClub.WebAPI.Controllers
{
    public class ProductTypesController : BaseCRUDController<ProductTypeResponse, ProductTypeSearchObject, ProductTypeInsertRequest, ProductTypeUpdateRequest>
    {
        public ProductTypesController(IProductTypeService service) : base(service)
        {
        }
    }
}
