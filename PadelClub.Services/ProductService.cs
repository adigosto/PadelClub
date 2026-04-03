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

        protected override IQueryable<DbProduct> ApplyFilter(IQueryable<DbProduct> query, ProductSearchObject search)
        {
            if (!string.IsNullOrWhiteSpace(search.Name))
            {
                query = query.Where(x => x.Name.Contains(search.Name));
            }
            if (!string.IsNullOrWhiteSpace(search.NameGTE))
            {
                query = query.Where(x => x.Name.StartsWith(search.NameGTE));
            }

            if (!string.IsNullOrWhiteSpace(search.FTS))
            {
                query = query.Where(x =>
                    x.Name.Contains(search.FTS) ||
                    x.Description.Contains(search.FTS));
            }

            return base.ApplyFilter(query, search);
        }

    }
}
