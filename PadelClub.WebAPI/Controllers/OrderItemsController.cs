using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;
using Microsoft.AspNetCore.Authorization;

namespace PadelClub.WebAPI.Controllers
{
    [Authorize(Policy = "AdminOnly")]
    public class OrderItemsController : BaseCRUDController<OrderItemResponse, OrderItemSearchObject, OrderItemInsertRequest, OrderItemUpdateRequest>
    {
        public OrderItemsController(IOrderItemService service) : base(service)
        {
        }
    }
}
