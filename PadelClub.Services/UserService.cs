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

        protected override IQueryable<User> ApplyFilter(IQueryable<User> query, UserSearchObject search)
        {
            if (!string.IsNullOrWhiteSpace(search.Username))
            {
                query = query.Where(x => x.Username.Contains(search.Username));
            }

            if (!string.IsNullOrWhiteSpace(search.Email))
            {
                query = query.Where(x => x.Email.Contains(search.Email));
            }

            if (!string.IsNullOrWhiteSpace(search.FirstName))
            {
                query = query.Where(x => x.FirstName.Contains(search.FirstName));
            }

            if (!string.IsNullOrWhiteSpace(search.LastName))
            {
                query = query.Where(x => x.LastName.Contains(search.LastName));
            }

            if (!string.IsNullOrWhiteSpace(search.PhoneNumber))
            {
                query = query.Where(x => x.PhoneNumber != null && x.PhoneNumber.Contains(search.PhoneNumber));
            }

            if (search.IsActive.HasValue)
            {
                query = query.Where(x => x.IsActive == search.IsActive.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.FTS))
            {
                query = query.Where(x =>
                    x.Username.Contains(search.FTS) ||
                    x.Email.Contains(search.FTS) ||
                    x.FirstName.Contains(search.FTS) ||
                    x.LastName.Contains(search.FTS) ||
                    (x.PhoneNumber != null && x.PhoneNumber.Contains(search.FTS)));
            }

            return base.ApplyFilter(query, search);
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

