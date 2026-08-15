using Microsoft.AspNetCore.Mvc;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;
using System.Security.Claims;

namespace PadelClub.WebAPI.Controllers
{
    public class ClubReviewsController : BaseController<ClubReviewResponse, ClubReviewSearchObject>
    {
        private readonly IClubReviewService _reviewService;

        public ClubReviewsController(IClubReviewService service) : base(service)
        {
            _reviewService = service;
        }

        [HttpGet("mine")]
        public async Task<ActionResult<ClubReviewResponse>> Mine()
        {
            var review = await _reviewService.GetForUserAsync(CurrentUserId());
            return review == null ? NotFound() : Ok(review);
        }

        [HttpPut("mine")]
        public async Task<ActionResult<ClubReviewResponse>> SaveMine([FromBody] ClubReviewRequest request)
        {
            return Ok(await _reviewService.UpsertForUserAsync(CurrentUserId(), request));
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
