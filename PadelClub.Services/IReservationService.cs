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
        Task<ReservationResponse?> CancelAsync(int id, int userId, bool isAdministrator);
        Task<List<ReservationResponse>> CreateRecurringAsync(int userId, RecurringReservationRequest request);
        Task<WaitlistEntryResponse> JoinWaitlistAsync(int userId, WaitlistRequest request);
        Task<List<WaitlistEntryResponse>> GetWaitlistAsync(int userId);
        Task<List<AccountCreditResponse>> GetCreditsAsync(int userId);
        Task<int> AddMaintenanceBlockAsync(MaintenanceBlockRequest request);
        Task<bool> MarkNoShowAsync(int reservationId);
    }
}
