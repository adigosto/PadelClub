using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using PadelClub.Services.IService;
using System.Collections.Generic;
using System.Threading.Tasks;
using User = PadelClub.Services.Database.User;

namespace PadelClub.Services
{
    public interface IUserService : ICRUDService<UserResponse, UserSearchObject, UserInsertRequest, UserUpdateRequest>
    {
        
    }
}

