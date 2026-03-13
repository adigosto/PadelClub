using PadelClub.Model;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using System.Collections.Generic;
using System.Threading.Tasks;
using User = PadelClub.Services.Database.User;

namespace PadelClub.Services
{
    public interface IUserService
    {
        Task<List<UserResponse>> Get(UserSearchObject? search);
        Task<UserResponse?> GetById(int id);
        Task<UserResponse> Create(UserRequest request);
        Task<UserResponse?> Update(int id, UserRequest request);
        Task<bool> Delete(int id);
        UserResponse? MapToResponse(User user);
    }
}

