using Microsoft.EntityFrameworkCore;
using PadelClub.Model;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using User = PadelClub.Services.Database.User;

namespace PadelClub.Services
{
    public class UserService : IUserService
    {
        private readonly PadelClubContext _dbContext;
        private readonly IPasswordHasher _passwordHasher;

        public UserService(PadelClubContext dbContext, IPasswordHasher passwordHasher)
        {
            _dbContext = dbContext;
            _passwordHasher = passwordHasher;
        }

        public async Task<List<UserResponse>> Get(UserSearchObject? search)
        {
            var query = _dbContext.Users.AsNoTracking().AsQueryable();

            if (search != null)
            {
                if (!string.IsNullOrWhiteSpace(search.Username))
                {
                    query = query.Where(u => u.Username.Contains(search.Username));
                }

                if (!string.IsNullOrWhiteSpace(search.Email))
                {
                    query = query.Where(u => u.Email.Contains(search.Email));
                }

                if (!string.IsNullOrWhiteSpace(search.FirstName))
                {
                    query = query.Where(u => u.FirstName.Contains(search.FirstName));
                }

                if (!string.IsNullOrWhiteSpace(search.LastName))
                {
                    query = query.Where(u => u.LastName.Contains(search.LastName));
                }

                if (!string.IsNullOrWhiteSpace(search.PhoneNumber))
                {
                    query = query.Where(u => u.PhoneNumber != null && u.PhoneNumber.Contains(search.PhoneNumber));
                }

                if (search.IsActive.HasValue)
                {
                    query = query.Where(u => u.IsActive == search.IsActive.Value);
                }

                if (!string.IsNullOrWhiteSpace(search.FTS))
                {
                    query = query.Where(u => 
                        u.Username.Contains(search.FTS) ||
                        u.Email.Contains(search.FTS) ||
                        u.FirstName.Contains(search.FTS) ||
                        u.LastName.Contains(search.FTS) ||
                        (u.PhoneNumber != null && u.PhoneNumber.Contains(search.FTS)));
                }
            }

            var users = await query.ToListAsync();
            return users.Select(u => MapToResponse(u)!).ToList();
        }

        public async Task<UserResponse?> GetById(int id)
        {
            var user = await _dbContext.Users.FindAsync(id);
            if (user == null)
                return null;
            return MapToResponse(user);
        }

        public async Task<UserResponse> Create(UserRequest request)
        {
            var user = new User
            {
                Username = request.Username,
                Email = request.Email,
                FirstName = request.FirstName,
                LastName = request.LastName,
                PhoneNumber = request.PhoneNumber,
                IsActive = request.IsActive
            };

            // Hash password if provided using PBKDF2
            // PBKDF2 uses a per-user random salt and a high iteration count
            if (!string.IsNullOrEmpty(request.Password))
            {
                user.PasswordHash = _passwordHasher.HashPassword(request.Password);
                // The PBKDF2 hash format already includes iteration count and salt,
                // so we don't need a separate salt field. Kept only for backward compatibility.
                user.PasswordSalt = string.Empty;
            }
            else
            {
                // Generate a placeholder hash for users without passwords (e.g., OAuth users)
                user.PasswordHash = "NO_PASSWORD_" + Guid.NewGuid().ToString("N");
                user.PasswordSalt = string.Empty;
            }

            _dbContext.Users.Add(user);
            await _dbContext.SaveChangesAsync();
            return MapToResponse(user)!;
        }

        public async Task<UserResponse?> Update(int id, UserRequest request)
        {
            var existingUser = await _dbContext.Users.FindAsync(id);
            if (existingUser == null)
                return null;

            existingUser.Username = request.Username;
            existingUser.Email = request.Email;
            existingUser.FirstName = request.FirstName;
            existingUser.LastName = request.LastName;
            existingUser.PhoneNumber = request.PhoneNumber;
            existingUser.IsActive = request.IsActive;
            existingUser.UpdatedAt = DateTime.UtcNow;

            // Hash password if provided using PBKDF2
            // PBKDF2 uses a per-user random salt and a high iteration count
            if (!string.IsNullOrEmpty(request.Password))
            {
                existingUser.PasswordHash = _passwordHasher.HashPassword(request.Password);
                // The PBKDF2 hash format already includes iteration count and salt,
                // so we don't need a separate salt field.
                existingUser.PasswordSalt = string.Empty;
            }
            // If password is not provided and user has no existing hash, keep it as is
            // (don't generate placeholder - user might be using OAuth or other auth methods)

            await _dbContext.SaveChangesAsync();
            return MapToResponse(existingUser);
        }

        public async Task<bool> Delete(int id)
        {
            var user = await _dbContext.Users.FindAsync(id);
            if (user == null)
                return false;

            _dbContext.Users.Remove(user);
            await _dbContext.SaveChangesAsync();
            return true;
        }

        public UserResponse? MapToResponse(User user)
        {
            if (user == null)
                return null;

            return new UserResponse
            {
                Id = user.Id,
                Username = user.Username,
                Email = user.Email,
                FirstName = user.FirstName,
                LastName = user.LastName,
                PhoneNumber = user.PhoneNumber,
                IsActive = user.IsActive,
                CreatedAt = user.CreatedAt,
                UpdatedAt = user.UpdatedAt
            };
        }
    }
}

