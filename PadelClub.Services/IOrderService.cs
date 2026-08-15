using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.IService;

namespace PadelClub.Services
{
    public interface IOrderService : ICRUDService<OrderResponse, OrderSearchObject, OrderInsertRequest, OrderUpdateRequest>
    {
        Task<OrderResponse> CheckoutAsync(int userId, CheckoutRequest request);
        Task<PadelClub.Model.Responses.PagedResult<OrderResponse>> GetForUserAsync(int userId, OrderSearchObject search);
    }
}
