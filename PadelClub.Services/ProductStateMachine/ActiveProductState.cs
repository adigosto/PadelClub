using MapsterMapper;
using PadelClub.Model.Exceptions;
using PadelClub.Model.Responses;
using PadelClub.Services.Database;

namespace PadelClub.Services.ProductStateMachine
{
    public class ActiveProductState : BaseProductState
    {
        public ActiveProductState(IServiceProvider serviceProvider, PadelClubContext dbContext, IMapper mapper) : base(serviceProvider, dbContext, mapper)
        {
        }

        public override async Task<ProductResponse> DeactivateAsync(int id)
        {
            var entity = await _dbContext.Products.FindAsync(id);
            if (entity == null)
                throw new UserException("Product not found.");

            entity.ProductState = nameof(DeactivatedProductState);

            await _dbContext.SaveChangesAsync();

            return _mapper.Map<ProductResponse>(entity);
        }
    }
}