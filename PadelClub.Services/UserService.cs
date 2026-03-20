using Microsoft.EntityFrameworkCore;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using User = PadelClub.Services.Database.User;

namespace PadelClub.Services
{
    public class UserService : BaseCRUDService<UserResponse, UserSearchObject, User, UserInsertRequest, UserUpdateRequest>, IUserService
    {
        private readonly IPasswordHasher _passwordHasher;

        public UserService(PadelClubContext dbContext, IPasswordHasher passwordHasher) : base(dbContext)
        {
            _passwordHasher = passwordHasher;
        }

        protected override User MapInsertToEntity(User entity, UserInsertRequest request)
        {
            entity.Username = request.Username;
            entity.Email = request.Email;
            entity.FirstName = request.FirstName;
            entity.LastName = request.LastName;
            entity.PhoneNumber = request.PhoneNumber;
            entity.PasswordHash = _passwordHasher.HashPassword(request.Password);
            // PasswordHasher.HashPassword embeds the salt in the returned string, so we keep PasswordSalt in sync.
            entity.PasswordSalt = ExtractSaltFromPasswordHash(entity.PasswordHash);
            entity.CreatedAt = DateTime.UtcNow;
            return entity;
        }

        protected override void MapUpdateToEntity(User entity, UserUpdateRequest request)
        {
            entity.Username = request.Username;
            entity.Email = request.Email;
            entity.FirstName = request.FirstName;
            entity.LastName = request.LastName;
            entity.PhoneNumber = request.PhoneNumber;
            entity.IsActive = request.IsActive;
            entity.UpdatedAt = DateTime.UtcNow;
        }

        protected override UserResponse MapToResponse(User entity)
        {
            return new UserResponse
            {
                Username = entity.Username,
                Email = entity.Email,
                FirstName = entity.FirstName,
                LastName = entity.LastName,
                PhoneNumber = entity.PhoneNumber,
            };
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

