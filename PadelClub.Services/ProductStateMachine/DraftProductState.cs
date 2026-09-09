using MapsterMapper;
using System.Text.Json;
using PadelClub.Model.Exceptions;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Services.Database;
using PadelClub.Model.Messages;
using PadelClub.Services.Outbox;

namespace PadelClub.Services.ProductStateMachine
{
    public class DraftProductState : BaseProductState
    {
        public DraftProductState(IServiceProvider serviceProvider, PadelClubContext dbContext, IMapper mapper) : base(serviceProvider, dbContext, mapper) { }

        public override async Task<ProductResponse> UpdateAsync(int id, ProductUpdateRequest request)
        {
            var entity = await _dbContext.Products.FindAsync(id);

            if (entity == null)
                throw new UserException("Product not found.");

            _mapper.Map(request, entity);

            var response = _mapper.Map<ProductResponse>(entity);
            var productUpdated = new ProductUpdated
            {
                EventId = Guid.NewGuid(),
                Product = response
            };

            // The product update and its publication intent are persisted in
            // one SaveChanges transaction. A hosted publisher delivers this
            // record later, so a broker outage cannot leave a committed product
            // change without a durable retryable event.
            _dbContext.OutboxMessages.Add(new OutboxMessage
            {
                Id = productUpdated.EventId,
                Type = OutboxMessageTypes.ProductUpdated,
                Payload = JsonSerializer.Serialize(productUpdated),
                OccurredAtUtc = DateTime.UtcNow,
                NextAttemptAtUtc = DateTime.UtcNow
            });
            await _dbContext.SaveChangesAsync();

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
