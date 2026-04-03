using MapsterMapper;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using DbProductType = PadelClub.Services.Database.ProductType;

namespace PadelClub.Services
{
    public class ProductTypeService : BaseCRUDService<ProductTypeResponse, ProductTypeSearchObject, DbProductType, ProductTypeInsertRequest, ProductTypeUpdateRequest>, IProductTypeService
    {
        public ProductTypeService(PadelClubContext dbContext, IMapper mapper) : base(dbContext, mapper)
        {
        }

        protected override IQueryable<DbProductType> ApplyFilter(IQueryable<DbProductType> query, ProductTypeSearchObject search)
        {
            if (!string.IsNullOrWhiteSpace(search.Name))
            {
                query = query.Where(x => x.Name.Contains(search.Name));
            }

            if (search.IsActive.HasValue)
            {
                query = query.Where(x => x.IsActive == search.IsActive.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.FTS))
            {
                query = query.Where(x =>
                    x.Name.Contains(search.FTS) ||
                    (x.Description != null && x.Description.Contains(search.FTS)));
            }

            return base.ApplyFilter(query, search);
        }
    }
}
