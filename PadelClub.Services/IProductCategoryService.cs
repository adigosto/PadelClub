using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.IService;

namespace PadelClub.Services
{
    public interface IProductCategoryService : ICRUDService<ProductCategoryResponse, ProductCategorySearchObject, ProductCategoryInsertRequest, ProductCategoryUpdateRequest>
    {
    }
}
