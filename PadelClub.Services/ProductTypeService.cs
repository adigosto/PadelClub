using MapsterMapper;
using Microsoft.Extensions.Logging;
using PadelClub.Model;
using PadelClub.Model.Exceptions;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using DbProductType = PadelClub.Services.Database.ProductType;

namespace PadelClub.Services
{
    public class ProductTypeService : BaseCRUDService<ProductTypeResponse, ProductTypeSearchObject, DbProductType, ProductTypeInsertRequest, ProductTypeUpdateRequest>, IProductTypeService
    {
        private readonly ILogger<ProductTypeService> _logger;
        public ProductTypeService(PadelClubContext dbContext, ILogger<ProductTypeService> logger, IMapper mapper) : base(dbContext, mapper)
        {
            _logger = logger;
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

        public override Task<ProductTypeResponse> CreateAsync(ProductTypeInsertRequest request)
        {
            _logger.LogInformation($"Attempt to create a new product type through the API was blocked. {request.Name}");
            throw new UserException("Product types cannot be created through the API.");
        }
       
    }
}
