using PadelClub.WebAPI.Workflows;
using PadelClub.Model.Requests;
using System.Numerics;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PadelClub.Model.Responses;
using PadelClub.Services;
using PadelClub.WebAPI.Commerce;
using PadelClub.WebAPI.Payments;

namespace PadelClub.WebAPI.Controllers;

[ApiController]
[Route("Commerce")]
[Authorize]
public sealed class CommerceOperationsController(CommerceOperationsWorkflow workflow) : ControllerBase
{
    [HttpPost("inventory/{productId:int}/adjust")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<IActionResult> AdjustInventory(int productId, InventoryAdjustmentRequest request, CancellationToken ct) => (await workflow.AdjustInventory(productId, request, ct)).ToHttp();

    [HttpGet("inventory/{productId:int}/history")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<ActionResult<object>> InventoryHistory(int productId, CancellationToken ct) => (await workflow.InventoryHistory(productId, ct)).ToHttp();

    [HttpPost("coupons")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<ActionResult<object>> CreateCoupon(CouponRequest request, CancellationToken ct) => (await workflow.CreateCoupon(request, ct)).ToHttp();

    [HttpPut("coupons/{id:int}")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<IActionResult> UpdateCoupon(int id, CouponRequest request, CancellationToken ct) => (await workflow.UpdateCoupon(id, request, ct)).ToHttp();

    [HttpGet("coupons")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<ActionResult<object>> Coupons(CancellationToken ct) => (await workflow.Coupons(ct)).ToHttp();

    [HttpPost("returns")]
    public async Task<ActionResult<object>> RequestReturn(ReturnCreateRequest request, CancellationToken ct) => (await workflow.RequestReturn(request, ct)).ToHttp();

    [HttpGet("returns/eligible-orders/mine")]
    public async Task<ActionResult<IReadOnlyList<EligibleReturnOrderResponse>>> EligibleReturnOrders(CancellationToken ct) => (await workflow.EligibleReturnOrders(ct)).ToHttp();

    [HttpGet("returns/mine")]
    public async Task<ActionResult<object>> MyReturns(CancellationToken ct) => (await workflow.MyReturns(ct)).ToHttp();

    [HttpGet("returns")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<ActionResult<object>> Returns([FromQuery] string? status, CancellationToken ct) => (await workflow.Returns(status, ct)).ToHttp();

    [HttpPut("returns/{id:int}/resolve")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<IActionResult> ResolveReturn(int id, ReturnResolutionRequest request, CancellationToken ct) => (await workflow.ResolveReturn(id, request, ct)).ToHttp();
}
