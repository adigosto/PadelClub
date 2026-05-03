using MapsterMapper;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Services.Database;

namespace PadelClub.Services.ProductStateMachine
{
    public class InitialProductState : BaseProductState
    {
        public InitialProductState(IServiceProvider serviceProvider, PadelClubContext dbContext, IMapper mapper) : base(serviceProvider, dbContext, mapper)
        {
        }

        public override async Task<ProductResponse> CreateAsync(ProductInsertRequest request)
        {
            var entity = new Product();
            _mapper.Map(request, entity);

            entity.ProductState = "DraftProductState";

            _dbContext.Products.Add(entity);
            await _dbContext.SaveChangesAsync();

            return _mapper.Map<ProductResponse>(entity);
        }
    }
}