using System.Security.Claims;

namespace PadelClub.WebAPI.Authentication;

public interface ICurrentUser
{
    int Id { get; }
    bool IsAdministrator { get; }
}

public sealed class CurrentUser(IHttpContextAccessor accessor) : ICurrentUser
{
    public int Id => int.TryParse(accessor.HttpContext?.User.FindFirstValue(ClaimTypes.NameIdentifier), out var id)
        ? id : throw new UnauthorizedAccessException();
    public bool IsAdministrator => accessor.HttpContext?.User.IsInRole("Administrator") == true;
}
