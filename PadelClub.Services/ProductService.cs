using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using Microsoft.EntityFrameworkCore;
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

        protected override async Task BeforeInsert(DbProduct entity, ProductInsertRequest request)
        {
            entity.ProductCategoryId = await ResolveCategoryIdAsync(request.ProductCategoryId);
            entity.ProductTypeId = await ResolveTypeIdAsync(request.ProductTypeId);
        }

        protected override async Task BeforeUpdate(DbProduct entity, ProductUpdateRequest request)
        {
            entity.ProductCategoryId = await ResolveCategoryIdAsync(request.ProductCategoryId, entity.ProductCategoryId);
            entity.ProductTypeId = await ResolveTypeIdAsync(request.ProductTypeId, entity.ProductTypeId);
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

        private async Task<int> ResolveCategoryIdAsync(int? requestedCategoryId, int? currentCategoryId = null)
        {
            var categoryId = requestedCategoryId.GetValueOrDefault(currentCategoryId.GetValueOrDefault());
            if (categoryId > 0)
            {
                var exists = await _dbContext.ProductCategories.AnyAsync(x => x.Id == categoryId && x.IsActive);
                if (!exists)
                {
                    throw new InvalidOperationException($"Invalid ProductCategoryId: {categoryId}.");
                }

                return categoryId;
            }

            var fallbackId = await _dbContext.ProductCategories
                .Where(x => x.IsActive)
                .OrderBy(x => x.Id)
                .Select(x => x.Id)
                .FirstOrDefaultAsync();

            if (fallbackId <= 0)
            {
                throw new InvalidOperationException("No active product categories exist. Create a category first.");
            }

            return fallbackId;
        }

        private async Task<int> ResolveTypeIdAsync(int? requestedTypeId, int? currentTypeId = null)
        {
            var typeId = requestedTypeId.GetValueOrDefault(currentTypeId.GetValueOrDefault());
            if (typeId > 0)
            {
                var exists = await _dbContext.ProductTypes.AnyAsync(x => x.Id == typeId && x.IsActive);
                if (!exists)
                {
                    throw new InvalidOperationException($"Invalid ProductTypeId: {typeId}.");
                }

                return typeId;
            }

            var fallbackId = await _dbContext.ProductTypes
                .Where(x => x.IsActive)
                .OrderBy(x => x.Id)
                .Select(x => x.Id)
                .FirstOrDefaultAsync();

            if (fallbackId <= 0)
            {
                throw new InvalidOperationException("No active product types exist. Create a product type first.");
            }

            return fallbackId;
        }

    }
}
