using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Services;
using PadelClub.Services.Database;

namespace PadelClub.WebAPI.Authentication;

public sealed class AuthService(
    PadelClubContext db,
    IUserService users,
    IPasswordHasher passwordHasher,
    IOptions<AuthOptions> options,
    ITransactionalEmailSender emailSender) : IAuthService
{
    private readonly AuthOptions _options = options.Value;

    public async Task<AuthResponse?> LoginAsync(UserLoginRequest request, CancellationToken cancellationToken)
    {
        var response = await users.AuthenticateAsync(request);
        if (response is null || !response.IsActive) return null;
        return await CreateSessionAsync(response, cancellationToken);
    }

    public async Task<AuthResponse?> RefreshAsync(string refreshToken, CancellationToken cancellationToken)
    {
        var hash = Hash(refreshToken);
        var stored = await db.AuthTokens.Include(x => x.User).ThenInclude(x => x.UserRoles)
            .ThenInclude(x => x.Role).SingleOrDefaultAsync(x => x.TokenHash == hash && x.Purpose == "refresh", cancellationToken);
        if (stored is null || stored.RevokedAt is not null || stored.ExpiresAt <= DateTime.UtcNow || !stored.User.IsActive)
            return null;
        if (stored.ConsumedAt is not null)
        {
            if (stored.FamilyId is not null)
                await db.AuthTokens.Where(x => x.FamilyId == stored.FamilyId && x.RevokedAt == null)
                    .ExecuteUpdateAsync(x => x.SetProperty(t => t.RevokedAt, DateTime.UtcNow), cancellationToken);
            return null;
        }

        var consumedAt = DateTime.UtcNow;
        var claimed = await db.AuthTokens.Where(x => x.Id == stored.Id && x.ConsumedAt == null && x.RevokedAt == null && x.ExpiresAt > consumedAt)
            .ExecuteUpdateAsync(x => x.SetProperty(t => t.ConsumedAt, consumedAt), cancellationToken);
        if (claimed != 1) return null;
        stored.ConsumedAt = consumedAt;
        var user = await users.GetByIdAsync(stored.UserId);
        if (user is null) return null;
        var result = await CreateSessionAsync(user, cancellationToken, stored.FamilyId);
        stored.ReplacedByTokenId = await db.AuthTokens.Where(x => x.TokenHash == Hash(result.RefreshToken)).Select(x => x.Id).SingleAsync(cancellationToken);
        await db.SaveChangesAsync(cancellationToken);
        return result;
    }

    public async Task LogoutAsync(string refreshToken, int? userId, CancellationToken cancellationToken)
    {
        var hash = Hash(refreshToken);
        var token = await db.AuthTokens.SingleOrDefaultAsync(x => x.TokenHash == hash && x.Purpose == "refresh", cancellationToken);
        if (token is not null && (userId is null || token.UserId == userId))
        {
            token.RevokedAt = DateTime.UtcNow;
            await db.SaveChangesAsync(cancellationToken);
        }
    }

    public async Task RequestPasswordResetAsync(string email, CancellationToken cancellationToken)
    {
        var user = await db.Users.SingleOrDefaultAsync(x => x.Email == email && x.IsActive, cancellationToken);
        if (user is null) return;
        var token = await CreateOpaqueTokenAsync(user.Id, "password-reset", TimeSpan.FromHours(1), cancellationToken);
        await emailSender.SendPasswordResetAsync(user.Email, token, cancellationToken);
    }

    public async Task<bool> ResetPasswordAsync(string token, string newPassword, CancellationToken cancellationToken)
    {
        if (newPassword.Length < 10) return false;
        var stored = await FindUsableAsync(token, "password-reset", cancellationToken);
        if (stored is null) return false;
        var hash = passwordHasher.HashPassword(newPassword);
        stored.User.PasswordHash = hash;
        stored.User.PasswordSalt = hash.Split('.')[1];
        stored.User.UpdatedAt = DateTime.UtcNow;
        stored.ConsumedAt = DateTime.UtcNow;
        await db.AuthTokens.Where(x => x.UserId == stored.UserId && x.Purpose == "refresh" && x.RevokedAt == null)
            .ExecuteUpdateAsync(x => x.SetProperty(t => t.RevokedAt, DateTime.UtcNow), cancellationToken);
        await db.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task RequestEmailVerificationAsync(int userId, CancellationToken cancellationToken)
    {
        var user = await db.Users.FindAsync([userId], cancellationToken);
        if (user is null || user.EmailVerifiedAt is not null) return;
        var token = await CreateOpaqueTokenAsync(user.Id, "email-verify", TimeSpan.FromHours(24), cancellationToken);
        await emailSender.SendEmailVerificationAsync(user.Email, token, cancellationToken);
    }

    public async Task<bool> VerifyEmailAsync(string token, CancellationToken cancellationToken)
    {
        var stored = await FindUsableAsync(token, "email-verify", cancellationToken);
        if (stored is null) return false;
        stored.User.EmailVerifiedAt = DateTime.UtcNow;
        stored.ConsumedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(cancellationToken);
        return true;
    }

    private async Task<AuthResponse> CreateSessionAsync(PadelClub.Model.UserResponse user, CancellationToken cancellationToken, string? familyId = null)
    {
        var expires = DateTime.UtcNow.AddMinutes(_options.AccessTokenMinutes);
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()), new(ClaimTypes.Name, user.Username),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString("N")),
            new("email_verified", user.IsEmailVerified ? "true" : "false")
        };
        claims.AddRange(user.Roles.Select(x => new Claim(ClaimTypes.Role, x.Name)));
        var credentials = new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_options.SigningKey)), SecurityAlgorithms.HmacSha256);
        var jwt = new JwtSecurityToken(_options.Issuer, _options.Audience, claims, expires: expires, signingCredentials: credentials);
        var refresh = await CreateOpaqueTokenAsync(user.Id, "refresh", TimeSpan.FromDays(_options.RefreshTokenDays), cancellationToken, familyId ?? Guid.NewGuid().ToString("N"));
        return new AuthResponse { AccessToken = new JwtSecurityTokenHandler().WriteToken(jwt), RefreshToken = refresh, AccessTokenExpiresAt = expires, User = user };
    }

    private async Task<string> CreateOpaqueTokenAsync(int userId, string purpose, TimeSpan lifetime, CancellationToken cancellationToken, string? familyId = null)
    {
        var token = Convert.ToBase64String(RandomNumberGenerator.GetBytes(48));
        db.AuthTokens.Add(new AuthToken { UserId = userId, TokenHash = Hash(token), Purpose = purpose, FamilyId = familyId, ExpiresAt = DateTime.UtcNow.Add(lifetime) });
        await db.SaveChangesAsync(cancellationToken);
        return token;
    }

    private Task<AuthToken?> FindUsableAsync(string token, string purpose, CancellationToken cancellationToken) =>
        db.AuthTokens.Include(x => x.User).SingleOrDefaultAsync(x => x.TokenHash == Hash(token) && x.Purpose == purpose && x.ConsumedAt == null && x.RevokedAt == null && x.ExpiresAt > DateTime.UtcNow, cancellationToken);

    private static string Hash(string token) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
}
