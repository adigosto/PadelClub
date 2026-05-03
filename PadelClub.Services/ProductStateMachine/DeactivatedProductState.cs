using MapsterMapper;
using PadelClub.Model.Exceptions;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Services.Database;

namespace PadelClub.Services.ProductStateMachine
{
    public class DeactivatedProductState : BaseProductState
    {
        public DeactivatedProductState(IServiceProvider serviceProvider, PadelClubContext dbContext, IMapper mapper) : base(serviceProvider, dbContext, mapper)
        {
        }

        public override async Task<ProductResponse> UpdateAsync(int id, ProductUpdateRequest request)
        {
            var entity = await _dbContext.Products.FindAsync(id);
            if (entity == null)
                throw new UserException("Product not found.");

            entity.ProductState = nameof(DraftProductState);

            await _dbContext.SaveChangesAsync();

            return _mapper.Map<ProductResponse>(entity);
        }

        public override async Task<ProductResponse> ActivateAsync(int id)
        {
            var entity = await _dbContext.Products.FindAsync(id);
            if (entity == null)
                throw new UserException("Product not found.");

            entity.ProductState = nameof(ActiveProductState);

            await _dbContext.SaveChangesAsync();

            return _mapper.Map<ProductResponse>(entity);
        }
    }
}