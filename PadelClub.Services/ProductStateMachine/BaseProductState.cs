using PadelClub.Model.Exceptions;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using Microsoft.Extensions.DependencyInjection;
using PadelClub.Services.Database;
using MapsterMapper;

namespace PadelClub.Services.ProductStateMachine
{
    public class BaseProductState
    {
        protected readonly IServiceProvider _serviceProvider;
        protected readonly PadelClubContext _dbContext;
        protected readonly IMapper _mapper;
        public BaseProductState(IServiceProvider serviceProvider, PadelClubContext dbContext, IMapper mapper)
        {
            _serviceProvider = serviceProvider;
            _dbContext = dbContext;
            _mapper = mapper;
        }

        public virtual Task<ProductResponse> CreateAsync(ProductInsertRequest request)
        {
            return Task.FromException<ProductResponse>(new UserException("Not allowed."));
        }

        public virtual Task<ProductResponse> UpdateAsync(int id, ProductUpdateRequest request)
        {
            return Task.FromException<ProductResponse>(new UserException("Not allowed."));
        }

        public virtual Task<ProductResponse> ActivateAsync(int id)
        {
            return Task.FromException<ProductResponse>(new UserException("Not allowed."));
        }

        
        public virtual Task<ProductResponse> DeactivateAsync(int id)
        {
            return Task.FromException<ProductResponse>(new UserException("Not allowed."));
        }

        public BaseProductState GetProductState(string stateName)
        {
            switch (stateName)  
            {
                case "InitialProductState":
                    return _serviceProvider.GetService<InitialProductState>() ?? throw new Exception("InitialProductState not found.");
                case "DraftProductState":
                    return _serviceProvider.GetService<DraftProductState>() ?? throw new Exception("DraftProductState not found.");
                case "ActiveProductState":
                    return _serviceProvider.GetService<ActiveProductState>() ?? throw new Exception("ActiveProductState not found.");
                case "DeactivatedProductState":
                    return _serviceProvider.GetService<DeactivatedProductState>() ?? throw new Exception("DeactivatedProductState not found.");

                default:
                    throw new Exception($"State {stateName} not found.");
            }
        }
    }
}