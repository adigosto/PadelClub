using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using DbNotification = PadelClub.Services.Database.Notification;

namespace PadelClub.Services
{
    public class NotificationService : BaseCRUDService<NotificationResponse, NotificationSearchObject, DbNotification, NotificationInsertRequest, NotificationUpdateRequest>, INotificationService
    {
        public NotificationService(PadelClubContext dbContext, IMapper mapper) : base(dbContext, mapper)
        {
        }

        public override async Task<PagedResult<NotificationResponse>> GetAsync(NotificationSearchObject search)
        {
            var query = ApplyFilter(
                _dbContext.Notifications
                    .AsNoTracking()
                    .Include(x => x.Recipients),
                search);

            int? totalCount = search.IncludeTotalCount ? await query.CountAsync() : null;
            query = query.OrderByDescending(x => x.CreatedAt);
            var page = Math.Max(search.Page.GetValueOrDefault(1), 1);
            var pageSize = search.PageSize.GetValueOrDefault(10);
            if (pageSize > 0)
            {
                query = query.Skip((page - 1) * pageSize).Take(pageSize);
            }

            var items = await query.ToListAsync();
            return new PagedResult<NotificationResponse>
            {
                Items = items.Select(item => MapToResponse(item)).ToList(),
                TotalCount = totalCount
            };
        }

        public override async Task<NotificationResponse?> GetByIdAsync(int id)
        {
            var entity = await _dbContext.Notifications
                .AsNoTracking()
                .Include(x => x.Recipients)
                .FirstOrDefaultAsync(x => x.Id == id);
            return entity == null ? null : MapToResponse(entity);
        }

        public override async Task<NotificationResponse> CreateAsync(NotificationInsertRequest request)
        {
            Validate(request.Title, request.Message, request.Type);
            var userIds = request.RecipientUserIds.Distinct().ToList();
            if (userIds.Count == 0)
            {
                userIds = await _dbContext.Users
                    .Where(x => x.IsActive)
                    .Select(x => x.Id)
                    .ToListAsync();
            }
            else
            {
                var existingIds = await _dbContext.Users
                    .Where(x => userIds.Contains(x.Id))
                    .Select(x => x.Id)
                    .ToListAsync();
                if (existingIds.Count != userIds.Count)
                {
                    throw new InvalidOperationException("One or more notification recipients do not exist.");
                }
                userIds = existingIds;
            }

            if (userIds.Count == 0)
            {
                throw new InvalidOperationException("A notification requires at least one recipient.");
            }

            var preferences = await _dbContext.NotificationPreferences
                .Where(x => userIds.Contains(x.UserId)).ToDictionaryAsync(x => x.UserId);
            var entity = new DbNotification
            {
                Title = request.Title.Trim(),
                Message = request.Message.Trim(),
                Type = request.Type.Trim(),
                CreatedAt = DateTime.UtcNow,
                Recipients = userIds.Where(userId => !preferences.TryGetValue(userId, out var preference) || preference.InAppEnabled)
                    .Select(userId => new NotificationRecipient
                {
                    UserId = userId
                }).ToList()
            };
            _dbContext.Notifications.Add(entity);
            foreach (var userId in userIds)
            {
                preferences.TryGetValue(userId, out var preference);
                if (preference?.EmailEnabled != false)
                    entity.Deliveries.Add(new NotificationDelivery { UserId = userId, Channel = "Email" });
                if (preference?.PushEnabled != false)
                    entity.Deliveries.Add(new NotificationDelivery { UserId = userId, Channel = "Push" });
            }
            await _dbContext.SaveChangesAsync();
            return MapToResponse(entity);
        }

        public override async Task<NotificationResponse?> UpdateAsync(int id, NotificationUpdateRequest request)
        {
            Validate(request.Title, request.Message, request.Type);
            var entity = await _dbContext.Notifications
                .Include(x => x.Recipients)
                .FirstOrDefaultAsync(x => x.Id == id);
            if (entity == null) return null;

            entity.Title = request.Title.Trim();
            entity.Message = request.Message.Trim();
            entity.Type = request.Type.Trim();
            entity.UpdatedAt = DateTime.UtcNow;
            await _dbContext.SaveChangesAsync();
            return MapToResponse(entity);
        }

        public async Task<PagedResult<NotificationResponse>> GetForUserAsync(int userId, NotificationSearchObject search)
        {
            var query = _dbContext.Notifications
                .AsNoTracking()
                .Include(x => x.Recipients)
                .Where(x => x.Recipients.Any(r => r.UserId == userId));
            query = ApplyCommonFilter(query, search);
            if (search.IsRead.HasValue)
            {
                query = query.Where(x => x.Recipients.Any(r =>
                    r.UserId == userId && r.IsRead == search.IsRead.Value));
            }

            int? totalCount = search.IncludeTotalCount ? await query.CountAsync() : null;
            query = query.OrderByDescending(x => x.CreatedAt);
            var page = Math.Max(search.Page.GetValueOrDefault(1), 1);
            var pageSize = search.PageSize.GetValueOrDefault(10);
            if (pageSize > 0)
            {
                query = query.Skip((page - 1) * pageSize).Take(pageSize);
            }

            var items = await query.ToListAsync();
            return new PagedResult<NotificationResponse>
            {
                Items = items.Select(item => MapToResponse(item, userId)).ToList(),
                TotalCount = totalCount
            };
        }

        public async Task<NotificationResponse?> MarkReadAsync(int notificationId, int userId)
        {
            var recipient = await _dbContext.NotificationRecipients
                .Include(x => x.Notification)
                .ThenInclude(x => x.Recipients)
                .FirstOrDefaultAsync(x => x.NotificationId == notificationId && x.UserId == userId);
            if (recipient == null) return null;

            if (!recipient.IsRead)
            {
                recipient.IsRead = true;
                recipient.ReadAt = DateTime.UtcNow;
                await _dbContext.SaveChangesAsync();
            }
            return MapToResponse(recipient.Notification, userId);
        }

        public async Task<int> MarkAllReadAsync(int userId)
        {
            var recipients = await _dbContext.NotificationRecipients
                .Where(x => x.UserId == userId && !x.IsRead)
                .ToListAsync();
            var readAt = DateTime.UtcNow;
            foreach (var recipient in recipients)
            {
                recipient.IsRead = true;
                recipient.ReadAt = readAt;
            }
            await _dbContext.SaveChangesAsync();
            return recipients.Count;
        }

        protected override IQueryable<DbNotification> ApplyFilter(IQueryable<DbNotification> query, NotificationSearchObject search)
        {
            query = ApplyCommonFilter(query, search);
            if (search.IsRead == true)
            {
                query = query.Where(x => x.Recipients.Any() && x.Recipients.All(r => r.IsRead));
            }
            else if (search.IsRead == false)
            {
                query = query.Where(x => x.Recipients.Any(r => !r.IsRead));
            }
            return query;
        }

        protected override NotificationResponse MapToResponse(DbNotification entity)
        {
            return MapToResponse(entity, null);
        }

        private static IQueryable<DbNotification> ApplyCommonFilter(
            IQueryable<DbNotification> query,
            NotificationSearchObject search)
        {
            if (!string.IsNullOrWhiteSpace(search.Type))
                query = query.Where(x => x.Type == search.Type);
            if (search.CreatedFrom.HasValue)
                query = query.Where(x => x.CreatedAt >= search.CreatedFrom.Value);
            if (search.CreatedTo.HasValue)
                query = query.Where(x => x.CreatedAt <= search.CreatedTo.Value);
            if (!string.IsNullOrWhiteSpace(search.FTS))
            {
                var term = search.FTS.Trim();
                query = query.Where(x => x.Title.Contains(term) || x.Message.Contains(term));
            }
            return query;
        }

        private static NotificationResponse MapToResponse(DbNotification entity, int? userId)
        {
            var recipient = userId.HasValue
                ? entity.Recipients.FirstOrDefault(x => x.UserId == userId.Value)
                : null;
            return new NotificationResponse
            {
                Id = entity.Id,
                Title = entity.Title,
                Message = entity.Message,
                Type = entity.Type,
                CreatedAt = entity.CreatedAt,
                UpdatedAt = entity.UpdatedAt,
                RecipientCount = entity.Recipients.Count,
                ReadCount = entity.Recipients.Count(x => x.IsRead),
                IsRead = recipient?.IsRead,
                ReadAt = recipient?.ReadAt
            };
        }

        private static void Validate(string title, string message, string type)
        {
            if (string.IsNullOrWhiteSpace(title))
                throw new InvalidOperationException("Notification title is required.");
            if (string.IsNullOrWhiteSpace(message))
                throw new InvalidOperationException("Notification message is required.");
            if (string.IsNullOrWhiteSpace(type))
                throw new InvalidOperationException("Notification type is required.");
            if (title.Trim().Length > 200 || message.Trim().Length > 2000 || type.Trim().Length > 50)
                throw new InvalidOperationException("Notification content exceeds the allowed length.");
        }
    }
}
