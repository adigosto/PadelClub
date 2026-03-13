using PadelClub.Model;
using PadelClub.Model.SearchObjects;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using User = PadelClub.Services.Database.User;

namespace PadelClub.Services
{
    public class DummyUserService : IUserService
    {
        public Task<List<UserResponse>> Get(UserSearchObject? search)
        {
            var users = new List<User>
            {
                new User()
                {
                    Id = 1,
                    Username = "john_doe",
                    Email = "john.doe@example.com",
                    FirstName = "John",
                    LastName = "Doe",
                    PasswordHash = "dummy_hash_1",
                    PasswordSalt = "dummy_salt_1",
                    PhoneNumber = "123-456-7890",
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow.AddDays(-30),
                    UpdatedAt = null
                },
                new User()
                {
                    Id = 2,
                    Username = "jane_smith",
                    Email = "jane.smith@example.com",
                    FirstName = "Jane",
                    LastName = "Smith",
                    PasswordHash = "dummy_hash_2",
                    PasswordSalt = "dummy_salt_2",
                    PhoneNumber = "987-654-3210",
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow.AddDays(-15),
                    UpdatedAt = DateTime.UtcNow.AddDays(-5)
                }
            };

            var query = users.AsQueryable();

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

            var userResponses = query.Select(u => MapToResponse(u)!).ToList();
            return Task.FromResult(userResponses);
        }

        public Task<UserResponse?> GetById(int id)
        {
            if (id == 1)
            {
                var user = new User()
                {
                    Id = 1,
                    Username = "john_doe",
                    Email = "john.doe@example.com",
                    FirstName = "John",
                    LastName = "Doe",
                    PasswordHash = "dummy_hash_1",
                    PasswordSalt = "dummy_salt_1",
                    PhoneNumber = "123-456-7890",
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow.AddDays(-30),
                    UpdatedAt = null
                };
                return Task.FromResult<UserResponse?>(MapToResponse(user));
            }

            return Task.FromResult<UserResponse?>(null);
        }

        public Task<UserResponse> Create(UserRequest request)
        {
            var user = new User
            {
                Id = 3,
                Username = request.Username,
                Email = request.Email,
                FirstName = request.FirstName,
                LastName = request.LastName,
                PhoneNumber = request.PhoneNumber,
                IsActive = request.IsActive,
                PasswordHash = !string.IsNullOrEmpty(request.Password) ? request.Password : "dummy_hash",
                PasswordSalt = !string.IsNullOrEmpty(request.Password) ? "salt" : "dummy_salt",
                CreatedAt = DateTime.UtcNow
            };

            return Task.FromResult(MapToResponse(user)!);
        }

        public Task<UserResponse?> Update(int id, UserRequest request)
        {
            if (id == 1)
            {
                var user = new User
                {
                    Id = 1,
                    Username = request.Username,
                    Email = request.Email,
                    FirstName = request.FirstName,
                    LastName = request.LastName,
                    PhoneNumber = request.PhoneNumber,
                    IsActive = request.IsActive,
                    PasswordHash = !string.IsNullOrEmpty(request.Password) ? request.Password : "dummy_hash",
                    PasswordSalt = !string.IsNullOrEmpty(request.Password) ? "salt" : "dummy_salt",
                    CreatedAt = DateTime.UtcNow.AddDays(-30),
                    UpdatedAt = DateTime.UtcNow
                };
                return Task.FromResult<UserResponse?>(MapToResponse(user));
            }

            return Task.FromResult<UserResponse?>(null);
        }

        public Task<bool> Delete(int id)
        {
            if (id == 1 || id == 2)
            {
                return Task.FromResult(true);
            }

            return Task.FromResult(false);
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

