using MapsterMapper;
using PadelClub.Model.Exceptions;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Services.Database;

namespace PadelClub.Services.ProductStateMachine
{
    public class DraftProductState : BaseProductState
    {
        public DraftProductState(IServiceProvider serviceProvider, PadelClubContext dbContext, IMapper mapper) : base(serviceProvider, dbContext, mapper)
        {
        }
        
        public override async Task<ProductResponse> UpdateAsync(int id, ProductUpdateRequest request)
        {
            var entity = await _dbContext.Products.FindAsync(id);
            if (entity == null)
                throw new UserException("Product not found.");

            _mapper.Map(request, entity);

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