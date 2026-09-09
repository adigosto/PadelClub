using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using PadelClub.Services.IService;
using System.Collections.Generic;
using System.Threading.Tasks;
using PadelClub.Model.Responses;
using Reservation = PadelClub.Services.Database.Reservation;

namespace PadelClub.Services
{
    public interface IReservationService : ICRUDService<ReservationResponse, ReservationSearchObject, ReservationInsertRequest, ReservationUpdateRequest>
    {
        Task<List<CourtAvailabilityResponse>> GetAvailabilityAsync(DateTime date);
        Task<PagedResult<ReservationResponse>> GetForUserAsync(int userId, ReservationSearchObject search);
        Task<ReservationResponse?> GetOwnedByIdAsync(int id, int userId, bool isAdministrator);
        Task<ReservationResponse?> CancelAsync(int id, int userId, bool isAdministrator, string reason);
        Task<List<ReservationResponse>> CreateRecurringAsync(int userId, RecurringReservationRequest request);
        Task<WaitlistEntryResponse> JoinWaitlistAsync(int userId, WaitlistRequest request);
        Task<List<WaitlistEntryResponse>> GetWaitlistAsync(int userId, int page = 1, int pageSize = 50);
        Task<List<AccountCreditResponse>> GetCreditsAsync(int userId, int page = 1, int pageSize = 50);
        Task<int> AddMaintenanceBlockAsync(MaintenanceBlockRequest request);
        Task<bool> MarkNoShowAsync(int reservationId, int actorUserId);
    }
}
