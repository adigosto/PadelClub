using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MapsterMapper;

namespace PadelClub.Services
{
    using DbProduct = PadelClub.Services.Database.Product;

    public class ProductService : BaseCRUDService<ProductResponse, ProductSearchObject, DbProduct, ProductInsertRequest, ProductUpdateRequest>, IProductService
    {
        public ProductService(PadelClubContext dbContext, IMapper mapper) : base(dbContext, mapper)
        {
        }
        
    }
}
