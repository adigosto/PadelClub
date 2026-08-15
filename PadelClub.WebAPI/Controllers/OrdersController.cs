using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;
using System.Security.Claims;

namespace PadelClub.WebAPI.Controllers
{
    public class OrdersController : BaseCRUDController<OrderResponse, OrderSearchObject, OrderInsertRequest, OrderUpdateRequest>
    {
        public OrdersController(IOrderService service) : base(service)
        {
        }

        [HttpGet]
        [Authorize(Policy = "AdminOnly")]
        public override Task<PadelClub.Model.Responses.PagedResult<OrderResponse>> Get(
            [FromQuery] OrderSearchObject? search) => base.Get(search);

        [HttpGet("{id:int}")]
        [Authorize(Policy = "AdminOnly")]
        public override Task<OrderResponse?> GetById(int id) => base.GetById(id);

        [HttpPost]
        [Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<OrderResponse>> Create([FromBody] OrderInsertRequest request)
            => base.Create(request);

        [HttpPut("{id:int}")]
        [Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<OrderResponse?>> Update(int id, [FromBody] OrderUpdateRequest request)
            => base.Update(id, request);

        [HttpDelete("{id:int}")]
        [Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<bool>> Delete(int id) => base.Delete(id);

        [HttpGet("mine")]
        public Task<PadelClub.Model.Responses.PagedResult<OrderResponse>> Mine(
            [FromQuery] OrderSearchObject? search)
        {
            return ((IOrderService)_crudService).GetForUserAsync(
                CurrentUserId(),
                search ?? new OrderSearchObject());
        }

        [HttpPost("checkout")]
        public async Task<ActionResult<OrderResponse>> Checkout([FromBody] CheckoutRequest request)
        {
            return Ok(await ((IOrderService)_crudService).CheckoutAsync(CurrentUserId(), request));
        }

        private int CurrentUserId()
        {
            var value = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (!int.TryParse(value, out var userId))
                throw new UnauthorizedAccessException("The authenticated user identifier is invalid.");
            return userId;
        }
    }
}
