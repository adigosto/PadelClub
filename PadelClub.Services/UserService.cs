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
using System.Security.Cryptography;

namespace PadelClub.Services
{
    public class UserService : BaseCRUDService<UserResponse, UserSearchObject, User, UserInsertRequest, UserUpdateRequest>, IUserService
    {
        private const int SaltSize = 16;
        private const int KeySize = 32;
        private const int Iterations = 100_000;
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

        private string HashPassword(string password, out byte[] salt)
        {
            salt = new byte[SaltSize];
            RandomNumberGenerator.Fill(salt);

            using var pbkdf2 = new Rfc2898DeriveBytes(password, salt, Iterations, HashAlgorithmName.SHA256);
            return Convert.ToBase64String(pbkdf2.GetBytes(KeySize));
        }

        protected override async Task BeforeInsert(User entity, UserInsertRequest request)
        {
            await EnsureUserIsUniqueAsync(null, request.Username, request.Email);

            if (string.IsNullOrWhiteSpace(request.Password))
            {
                throw new InvalidOperationException("Password is required.");
            }

            var passwordHash = HashPassword(request.Password, out var salt);
            entity.PasswordHash = passwordHash;
            entity.PasswordSalt = Convert.ToBase64String(salt);

            var roleIds = await ValidateRoleIdsAsync(request.RoleIds);
            entity.UserRoles = roleIds.Select(roleId => new UserRole
            {
                RoleId = roleId,
                DateAssigned = DateTime.UtcNow
            }).ToList();
        }

        protected override async Task BeforeUpdate(User entity, UserUpdateRequest request)
        {
            await EnsureUserIsUniqueAsync(entity.Id, request.Username, request.Email);

            if (!string.IsNullOrWhiteSpace(request.Password))
            {
                var passwordHash = HashPassword(request.Password, out var salt);
                entity.PasswordHash = passwordHash;
                entity.PasswordSalt = Convert.ToBase64String(salt);
            }

            var roleIds = await ValidateRoleIdsAsync(request.RoleIds);
            await ReplaceUserRolesAsync(entity.Id, roleIds);
        }

        private async Task EnsureUserIsUniqueAsync(int? userId, string username, string email)
        {
            var usernameExists = await _dbContext.Users.AnyAsync(x => x.Username == username && x.Id != userId.GetValueOrDefault());
            if (usernameExists)
            {
                throw new InvalidOperationException("Username already exists.");
            }

            var emailExists = await _dbContext.Users.AnyAsync(x => x.Email == email && x.Id != userId.GetValueOrDefault());
            if (emailExists)
            {
                throw new InvalidOperationException("Email already exists.");
            }
        }

        public async Task<UserResponse?> AuthenticateAsync(UserLoginRequest request)
        {
            var user = await _dbContext.Users
                .Include(x => x.UserRoles)
                .ThenInclude(x => x.Role)
                .FirstOrDefaultAsync(x => x.Username == request.Username);

            if (user == null || string.IsNullOrWhiteSpace(user.PasswordHash))
                return null;
            
            if(!VerifyPassword(request.Password, user.PasswordHash, user.PasswordSalt))
                return null;

            return MapUserToResponse(user);
        }

        public override async Task<UserResponse?> GetByIdAsync(int id)
        {
            var user = await _dbContext.Users
                .Include(x => x.UserRoles)
                .ThenInclude(x => x.Role)
                .FirstOrDefaultAsync(x => x.Id == id);

            if (user == null)
                return null;

            return MapUserToResponse(user);
        }

        public override async Task<UserResponse> CreateAsync(UserInsertRequest request)
        {
            var created = await base.CreateAsync(request);
            return await GetByIdAsync(created.Id) ?? created;
        }

        public override async Task<UserResponse?> UpdateAsync(int id, UserUpdateRequest request)
        {
            var updated = await base.UpdateAsync(id, request);
            if (updated == null)
                return null;

            return await GetByIdAsync(id) ?? updated;
        }

        private async Task<List<int>> ValidateRoleIdsAsync(IEnumerable<int>? roleIds)
        {
            var normalizedRoleIds = (roleIds ?? Enumerable.Empty<int>())
                .Where(x => x > 0)
                .Distinct()
                .ToList();

            if (normalizedRoleIds.Count == 0)
                return normalizedRoleIds;

            var existingRoleIds = await _dbContext.Roles
                .Where(x => x.IsActive && normalizedRoleIds.Contains(x.Id))
                .Select(x => x.Id)
                .ToListAsync();

            if (existingRoleIds.Count != normalizedRoleIds.Count)
            {
                var missingRoleIds = normalizedRoleIds.Except(existingRoleIds);
                throw new InvalidOperationException($"Invalid role IDs: {string.Join(", ", missingRoleIds)}.");
            }

            return existingRoleIds;
        }

        private async Task ReplaceUserRolesAsync(int userId, IEnumerable<int> roleIds)
        {
            var existingRoles = await _dbContext.UserRoles
                .Where(x => x.UserId == userId)
                .ToListAsync();

            if (existingRoles.Count > 0)
            {
                _dbContext.UserRoles.RemoveRange(existingRoles);
            }

            var newRoles = roleIds
                .Select(roleId => new UserRole
                {
                    UserId = userId,
                    RoleId = roleId,
                    DateAssigned = DateTime.UtcNow
                })
                .ToList();

            if (newRoles.Count > 0)
            {
                await _dbContext.UserRoles.AddRangeAsync(newRoles);
            }
        }

        private UserResponse MapUserToResponse(User user)
        {
            var response = _mapper.Map<UserResponse>(user);
            response.Roles = user.UserRoles
                .Where(x => x.Role != null && x.Role.IsActive)
                .Select(x => new RoleResponse
                {
                    Id = x.RoleId,
                    Name = x.Role.Name,
                    Description = x.Role.Description
                })
                .ToList();

            return response;
        }

        private bool VerifyPassword(string password, string passwordHash, string passwordSalt)
        {
            if (string.IsNullOrWhiteSpace(password) || string.IsNullOrWhiteSpace(passwordHash))
                return false;

            // Support combined hasher format: {iterations}.{base64(salt)}.{base64(derivedKey)}.
            if (passwordHash.Contains('.') && string.IsNullOrWhiteSpace(passwordSalt))
            {
                return _passwordHasher.VerifyPassword(password, passwordHash);
            }

            if (string.IsNullOrWhiteSpace(passwordSalt))
                return false;

            var saltBuffer = new byte[SaltSize * 4];
            var hashBuffer = new byte[KeySize * 4];

            if (!Convert.TryFromBase64String(passwordSalt, saltBuffer, out var saltBytesWritten))
                return false;

            if (!Convert.TryFromBase64String(passwordHash, hashBuffer, out var hashBytesWritten))
                return false;

            var salt = saltBuffer.AsSpan(0, saltBytesWritten).ToArray();
            var expectedHash = hashBuffer.AsSpan(0, hashBytesWritten).ToArray();

            using var pbkdf2 = new Rfc2898DeriveBytes(password, salt, Iterations, HashAlgorithmName.SHA256);
            var computedHash = pbkdf2.GetBytes(expectedHash.Length);
            return CryptographicOperations.FixedTimeEquals(computedHash, expectedHash);
        }
    }
}

