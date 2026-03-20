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

namespace PadelClub.Services
{
    using DbProduct = PadelClub.Services.Database.Product;

    public class ProductService : BaseCRUDService<ProductResponse, ProductSearchObject, DbProduct, ProductInsertRequest, ProductUpdateRequest>, IProductService
    {
        public ProductService(PadelClubContext dbContext) : base(dbContext)
        {
        }

        protected override DbProduct MapInsertToEntity(DbProduct entity, ProductInsertRequest request)
        {
            entity.Name = request.Name;
            entity.Description = request.Description;
            entity.Price = request.Price;
            entity.StockQuantity = request.StockQuantity;
            entity.ImageUrl = request.ImageUrl;
            
            // Your ProductInsertRequest DTO doesn't provide category/type IDs.
            // Default to the first available records so Product CRUD works.
            var categoryId = _dbContext.ProductCategories
                .OrderBy(c => c.Id)
                .Select(c => c.Id)
                .FirstOrDefault();
            var typeId = _dbContext.ProductTypes
                .OrderBy(t => t.Id)
                .Select(t => t.Id)
                .FirstOrDefault();

            if (categoryId == 0 || typeId == 0)
                throw new InvalidOperationException("Product categories/types must exist before creating products.");

            entity.ProductCategoryId = categoryId;
            entity.ProductTypeId = typeId;

            return entity;
        }

        protected override void MapUpdateToEntity(DbProduct entity, ProductUpdateRequest request)
        {
            entity.Name = request.Name;
            entity.Description = request.Description;
            entity.Price = request.Price;
            entity.StockQuantity = request.StockQuantity;
            entity.ImageUrl = request.ImageUrl;
        }

        
        protected override ProductResponse MapToResponse(DbProduct entity)
        {
            return new ProductResponse
            {
                Id = entity.Id,
                Name = entity.Name,
                Description = entity.Description,
                Price = entity.Price,
                StockQuantity = entity.StockQuantity,
                ImageUrl = entity.ImageUrl
            };
        }
    }
}
