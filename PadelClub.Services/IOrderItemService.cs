using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.IService;

namespace PadelClub.Services
{
    public interface IOrderItemService : ICRUDService<OrderItemResponse, OrderItemSearchObject, OrderItemInsertRequest, OrderItemUpdateRequest>
    {
    }
}
