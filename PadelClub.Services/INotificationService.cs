using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.Responses;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.IService;

namespace PadelClub.Services
{
    public interface INotificationService : ICRUDService<NotificationResponse, NotificationSearchObject, NotificationInsertRequest, NotificationUpdateRequest>
    {
        Task<PagedResult<NotificationResponse>> GetForUserAsync(int userId, NotificationSearchObject search);
        Task<NotificationResponse?> MarkReadAsync(int notificationId, int userId);
        Task<int> MarkAllReadAsync(int userId);
    }
}
