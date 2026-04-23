using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;
using PadelClub.Model.Requests;
using PadelClub.Services;
using System.Net.Http.Headers;
using System.Security.Claims;
using System.Text;
using System.Text.Encodings.Web;

namespace PadelClub.WebAPI.Filters
{
    class BasicAuthenticationHandler : AuthenticationHandler<AuthenticationSchemeOptions>
    {
        private readonly IUserService _userService;
        public BasicAuthenticationHandler(IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger, UrlEncoder encoder, ISystemClock clock, IUserService userService)
            : base(options, logger, encoder, clock)
        {
            _userService = userService;
        }

        protected override async Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            if (!Request.Headers.ContainsKey("Authorization"))
                return AuthenticateResult.NoResult();

            if (!AuthenticationHeaderValue.TryParse(Request.Headers["Authorization"], out var authHeader) ||
                authHeader == null ||
                !"Basic".Equals(authHeader.Scheme, StringComparison.OrdinalIgnoreCase) ||
                string.IsNullOrWhiteSpace(authHeader.Parameter))
            {
                return AuthenticateResult.Fail("Invalid Authorization header");
            }

            var authParamBuffer = new byte[authHeader.Parameter.Length];
            if (!Convert.TryFromBase64String(authHeader.Parameter, authParamBuffer, out var bytesWritten))
            {
                return AuthenticateResult.Fail("Invalid Authorization header");
            }

            var credentials = Encoding.UTF8.GetString(authParamBuffer, 0, bytesWritten).Split(':', 2);
            if (credentials.Length != 2 || string.IsNullOrWhiteSpace(credentials[0]))
            {
                return AuthenticateResult.Fail("Invalid Authorization header");
            }

            var username = credentials[0];
            var password = credentials[1];

            var user = await _userService.AuthenticateAsync(new UserLoginRequest
            {
                Username = username,
                Password = password
            });

            if (user == null)
                return AuthenticateResult.Fail("Invalid username or password");

            var claims = new[]
            {
                new Claim(ClaimTypes.NameIdentifier, user.Username.ToString()),
                new Claim(ClaimTypes.Name, user.FirstName),
            };

            if (user.Roles != null)
            {
                foreach (var role in user.Roles)
                {
                    claims = claims.Append(new Claim(ClaimTypes.Role, role.Name)).ToArray();
                }
            }

            var identity = new ClaimsIdentity(claims, Scheme.Name);
            var principal = new ClaimsPrincipal(identity);
            var ticket = new AuthenticationTicket(principal, Scheme.Name);

            return AuthenticateResult.Success(ticket);
        }
    }
}