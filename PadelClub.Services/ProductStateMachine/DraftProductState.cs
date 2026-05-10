using EasyNetQ;
using MapsterMapper;
using PadelClub.Model.Exceptions;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Services.Database;
using PadelClub.Model.Messages;

namespace PadelClub.Services.ProductStateMachine
{
    public class DraftProductState : BaseProductState
    {
        private readonly IBus _bus;
        public DraftProductState(IServiceProvider serviceProvider, PadelClubContext dbContext, IMapper mapper, IBus bus) : base(serviceProvider, dbContext, mapper)
        {
            _bus = bus;
        }

        public override async Task<ProductResponse> UpdateAsync(int id, ProductUpdateRequest request)
        {
            var entity = await _dbContext.Products.FindAsync(id);

            if (entity == null)
                throw new UserException("Product not found.");

            _mapper.Map(request, entity);

            await _dbContext.SaveChangesAsync();

            var response = _mapper.Map<ProductResponse>(entity);

            var productUpdated = new ProductUpdated
            {
                Product = response
            };

            await _bus.PubSub.PublishAsync(productUpdated);

            return response;
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