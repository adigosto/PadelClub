using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;
using System.Security.Claims;
using PadelClub.Model.Responses;
using PadelClub.WebAPI.Authentication;
using Microsoft.AspNetCore.RateLimiting;

namespace PadelClub.WebAPI.Controllers
{

    public class UsersController : BaseCRUDController<UserResponse, UserSearchObject, UserInsertRequest, UserUpdateRequest>
    {
        private readonly IUserService _userService;
        private readonly IAuthService _authService;
        public UsersController(IUserService service, IAuthService authService) : base(service)
        {
            _userService = service;
            _authService = authService;
        }

        [HttpGet]
        [Authorize(Policy = "AdminOnly")]
        public override Task<PadelClub.Model.Responses.PagedResult<UserResponse>> Get([FromQuery] UserSearchObject? search) => base.Get(search);

        [HttpGet("{id:int}")]
        [Authorize(Policy = "AdminOnly")]
        public override Task<UserResponse?> GetById(int id) => base.GetById(id);

        [HttpPost]
        [Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<UserResponse>> Create([FromBody] UserInsertRequest request) => base.Create(request);

        [HttpPut("{id:int}")]
        [Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<UserResponse?>> Update(int id, [FromBody] UserUpdateRequest request) => base.Update(id, request);

        [HttpDelete("{id:int}")]
        [Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<bool>> Delete(int id) => base.Delete(id);

        [HttpPost("login")]
        [AllowAnonymous]
        [EnableRateLimiting("Authentication")]
        public async Task<ActionResult<AuthResponse>> Login(UserLoginRequest request, CancellationToken cancellationToken)
        {
            var session = await _authService.LoginAsync(request, cancellationToken);
            if (session == null)
            {
                return Unauthorized();
            }
            return Ok(session);
        }

        [HttpPost("refresh")]
        [AllowAnonymous]
        [EnableRateLimiting("Authentication")]
        public async Task<ActionResult<AuthResponse>> Refresh(RefreshTokenRequest request, CancellationToken cancellationToken)
            => await _authService.RefreshAsync(request.RefreshToken, cancellationToken) is { } session ? Ok(session) : Unauthorized();

        [HttpPost("logout")]
        public async Task<IActionResult> Logout(LogoutRequest request, CancellationToken cancellationToken)
        {
            await _authService.LogoutAsync(request.RefreshToken, TryGetCurrentUserId(out var id) ? id : null, cancellationToken);
            return NoContent();
        }

        [HttpPost("forgot-password")]
        [AllowAnonymous]
        [EnableRateLimiting("Recovery")]
        public async Task<IActionResult> ForgotPassword(ForgotPasswordRequest request, CancellationToken cancellationToken)
        {
            await _authService.RequestPasswordResetAsync(request.Email.Trim(), cancellationToken);
            return Accepted();
        }

        [HttpPost("reset-password")]
        [AllowAnonymous]
        [EnableRateLimiting("Recovery")]
        public async Task<IActionResult> ResetPassword(ResetPasswordRequest request, CancellationToken cancellationToken)
            => await _authService.ResetPasswordAsync(request.Token, request.NewPassword, cancellationToken) ? NoContent() : BadRequest("Invalid or expired reset token.");

        [HttpPost("request-email-verification")]
        public async Task<IActionResult> RequestEmailVerification(CancellationToken cancellationToken)
        {
            if (!TryGetCurrentUserId(out var id)) return Unauthorized();
            await _authService.RequestEmailVerificationAsync(id, cancellationToken);
            return Accepted();
        }

        [HttpPost("verify-email")]
        [AllowAnonymous]
        [EnableRateLimiting("Recovery")]
        public async Task<IActionResult> VerifyEmail(VerifyEmailRequest request, CancellationToken cancellationToken)
            => await _authService.VerifyEmailAsync(request.Token, cancellationToken) ? NoContent() : BadRequest("Invalid or expired verification token.");

        [HttpGet("me")]
        public async Task<ActionResult<UserResponse>> GetMe()
        {
            if (!TryGetCurrentUserId(out var userId))
                return Unauthorized();

            var user = await _userService.GetByIdAsync(userId);
            return user == null ? NotFound() : Ok(user);
        }

        [HttpPut("me")]
        public async Task<ActionResult<UserResponse>> UpdateMe(UserSelfUpdateRequest request)
        {
            if (!TryGetCurrentUserId(out var userId))
                return Unauthorized();

            var current = await _userService.GetByIdAsync(userId);
            if (current == null)
                return NotFound();

            var updated = await _userService.UpdateAsync(userId, new UserUpdateRequest
            {
                Username = request.Username,
                Email = request.Email,
                FirstName = request.FirstName,
                LastName = request.LastName,
                PhoneNumber = request.PhoneNumber,
                Password = request.NewPassword,
                IsActive = current.IsActive,
                RoleIds = current.Roles.Select(role => role.Id).ToList()
            });

            return updated == null ? NotFound() : Ok(updated);
        }

        private bool TryGetCurrentUserId(out int userId)
        {
            return int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out userId);
        }
    }
}


