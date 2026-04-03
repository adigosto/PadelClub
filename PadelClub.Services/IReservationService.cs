using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using PadelClub.Services.IService;
using System.Collections.Generic;
using System.Threading.Tasks;
using Reservation = PadelClub.Services.Database.Reservation;

namespace PadelClub.Services
{
    public interface IReservationService : ICRUDService<ReservationResponse, ReservationSearchObject, ReservationInsertRequest, ReservationUpdateRequest>
    {
        
    }
}

