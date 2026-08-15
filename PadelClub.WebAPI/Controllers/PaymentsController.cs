using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;
using PadelClub.Model.Responses;

namespace PadelClub.WebAPI.Controllers
{
    public class PaymentsController : BaseCRUDController<PaymentResponse, PaymentSearchObject, PaymentInsertRequest, PaymentUpdateRequest>
    {
        public PaymentsController(IPaymentService service) : base(service)
        {
        }

        [HttpGet]
        [Authorize(Policy = "AdminOnly")]
        public override Task<PagedResult<PaymentResponse>> Get([FromQuery] PaymentSearchObject? search) => base.Get(search);

        [HttpGet("{id:int}")]
        [Authorize(Policy = "AdminOnly")]
        public override Task<PaymentResponse?> GetById(int id) => base.GetById(id);

        [HttpPost, Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<PaymentResponse>> Create([FromBody] PaymentInsertRequest request) => base.Create(request);
        [HttpPut("{id:int}"), Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<PaymentResponse?>> Update(int id, [FromBody] PaymentUpdateRequest request) => base.Update(id, request);
        [HttpDelete("{id:int}"), Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<bool>> Delete(int id) => base.Delete(id);

        [HttpGet("mine")]
        public Task<PagedResult<PaymentResponse>> Mine([FromQuery] PaymentSearchObject? search)
        {
            search ??= new PaymentSearchObject();
            search.UserId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
            return base.Get(search);
        }
    }
}
