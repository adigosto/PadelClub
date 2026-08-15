using PadelClub.Model.Requests;
using PadelClub.Model.Responses;

namespace PadelClub.WebAPI.Authentication;

public interface IAuthService
{
    Task<AuthResponse?> LoginAsync(UserLoginRequest request, CancellationToken cancellationToken);
    Task<AuthResponse?> RefreshAsync(string refreshToken, CancellationToken cancellationToken);
    Task LogoutAsync(string refreshToken, int? userId, CancellationToken cancellationToken);
    Task RequestPasswordResetAsync(string email, CancellationToken cancellationToken);
    Task<bool> ResetPasswordAsync(string token, string newPassword, CancellationToken cancellationToken);
    Task RequestEmailVerificationAsync(int userId, CancellationToken cancellationToken);
    Task<bool> VerifyEmailAsync(string token, CancellationToken cancellationToken);
}
