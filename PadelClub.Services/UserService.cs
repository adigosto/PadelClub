using Microsoft.EntityFrameworkCore;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using MapsterMapper;
using User = PadelClub.Services.Database.User;

namespace PadelClub.Services
{
    public class UserService : BaseCRUDService<UserResponse, UserSearchObject, User, UserInsertRequest, UserUpdateRequest>, IUserService
    {
        private readonly IPasswordHasher _passwordHasher;

        public UserService(PadelClubContext dbContext, IPasswordHasher passwordHasher, IMapper mapper) : base(dbContext, mapper)
        {
            _passwordHasher = passwordHasher;
        }

        private static string ExtractSaltFromPasswordHash(string hashedPassword)
        {
            if (string.IsNullOrWhiteSpace(hashedPassword))
                throw new ArgumentException("Password hash cannot be null/empty.", nameof(hashedPassword));

            var parts = hashedPassword.Split('.');
            // Expected format: {iterations}.{base64(salt)}.{base64(derivedKey)}
            if (parts.Length != 3)
                throw new ArgumentException("Invalid password hash format.", nameof(hashedPassword));

            // parts[1] is base64(salt)
            return parts[1];
        }
    }
}

